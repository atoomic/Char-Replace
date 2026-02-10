/*
*
* Copyright (c) 2018, cPanel, LLC.
* All rights reserved.
* http://cpanel.net
*
* This is free software; you can redistribute it and/or modify it under the
* same terms as Perl itself.
*
*/

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <embed.h>

#define IS_SPACE(c) ((c) == ' ' || (c) == '\n' || (c) == '\r' || (c) == '\t' || (c) == '\f')

/*
 * UTF8_SEQ_LEN: given a lead byte c (>= 0x80), return the expected
 * number of bytes in the UTF-8 sequence.  Continuation bytes (0x80-0xBF)
 * return 1 (copy-as-is).
 */
#define UTF8_SEQ_LEN(c) \
  ( (c) >= 0xFC ? 6 : \
    (c) >= 0xF8 ? 5 : \
    (c) >= 0xF0 ? 4 : \
    (c) >= 0xE0 ? 3 : \
    (c) >= 0xC0 ? 2 : 1 )

/*
 * ENSURE_ROOM: grow the reply SV's buffer so that at least need_bytes
 * more bytes can be written at ix_newstr.  Doubles str_size until it
 * fits, then refreshes the str pointer after SvGROW.
 */
#define ENSURE_ROOM(reply, str, str_size, ix_newstr, need_bytes) \
  do { \
    if ( (str_size) <= ((ix_newstr) + (need_bytes) + 1) ) { \
      STRLEN _target = (ix_newstr) + (need_bytes) + 1; \
      while ( (str_size) <= _target ) { \
        STRLEN _next = (str_size) * 2; \
        if ( _next <= (str_size) ) \
          croak("Char::Replace: string too large to allocate"); \
        (str_size) = _next; \
      } \
      SvGROW( (reply), (str_size) ); \
      (str) = SvPVX(reply); \
    } \
  } while (0)

SV *_replace_str( pTHX_ SV *sv, SV *map );
SV *_trim_sv( pTHX_ SV *sv );
IV _replace_inplace( pTHX_ SV *sv, SV *map );
IV _trim_inplace( pTHX_ SV *sv );

#define COMPILED_MAP_CLASS "Char::Replace::CompiledMap"

/*
 * _is_compiled_map: check if an SV is a compiled map (blessed PV ref).
 * If so, return a pointer to the 256-byte table.  Otherwise return NULL.
 */
static const char *_is_compiled_map( pTHX_ SV *map ) {
  SV *inner;
  if ( !map || !SvROK(map) )
    return NULL;
  inner = SvRV(map);
  if ( !SvOBJECT(inner) || !SvPOK(inner) )
    return NULL;
  if ( !sv_derived_from(map, COMPILED_MAP_CLASS) )
    return NULL;
  if ( SvCUR(inner) != 256 )
    return NULL;
  return SvPVX(inner);
}

/*
 * _build_fast_map: populate a 256-byte identity lookup table, then
 * overwrite entries according to the Perl map array.
 *
 * When is_utf8 is false and a map entry is a UTF-8 PV encoding a
 * Latin-1 codepoint (128-255), the codepoint is decoded to a single
 * byte so it can be used in the lookup table.
 *
 * Returns 1 if every map entry is a 1:1 byte replacement (fast-path
 * eligible).  Returns 0 if any entry requires expansion, deletion,
 * or is otherwise incompatible — the caller should fall through to
 * the general path.
 */
static int _build_fast_map( pTHX_ char fast_map[256], SV **ary, SSize_t map_top, int is_utf8 ) {
  int ix;
  SSize_t scan_top = map_top < 255 ? map_top : 255;

  for ( ix = 0; ix < 256; ++ix )
    fast_map[ix] = (char) ix;

  for ( ix = 0; ix <= scan_top; ++ix ) {
    SV *entry;
    if ( !ary[ix] )
      continue;
    entry = ary[ix];
    if ( SvPOK( entry ) ) {
      STRLEN slen;
      char *pv = SvPV( entry, slen );
      if ( slen == 1 ) {
        if ( is_utf8 && !SvUTF8( entry ) && ((unsigned char)pv[0]) >= 0x80 ) {
          /* Non-UTF-8 byte > 127 into UTF-8 output: needs 2-byte encoding */
          return 0;
        }
        fast_map[ix] = pv[0];
      } else if ( !is_utf8 && SvUTF8( entry ) && slen == 2 ) {
        /* UTF-8 encoded Latin-1 codepoint into non-UTF-8 output: decode */
        STRLEN retlen;
        UV cp = utf8_to_uvchr_buf( (U8*)pv, (U8*)(pv + slen), &retlen );
        if ( cp <= 255 && retlen == slen ) {
          fast_map[ix] = (char) cp;
        } else {
          return 0;
        }
      } else {
        return 0;
      }
    } else if ( SvIOK( entry ) || SvNOK( entry ) ) {
      IV val = SvIV( entry );
      if ( val >= 0 && val <= 255 ) {
        fast_map[ix] = (char) val;
      }
      /* out-of-range: keep identity (already set) */
    }
    /* code ref: not eligible for fast path */
    else if ( SvROK( entry ) && SvTYPE( SvRV( entry ) ) == SVt_PVCV ) {
      return 0;
    }
    /* undef/other: identity (already set) */
  }
  return 1;
}

SV *_trim_sv( pTHX_ SV *sv ) {
  STRLEN len;
  char *str = SvPV(sv, len);
  char *end;
  SV *reply;

  if ( len == 0 ) {
    reply = newSVpvn_flags( str, 0, SvUTF8(sv) );
    if ( SvTAINTED(sv) ) SvTAINTED_on(reply);
    return reply;
  }

  end = str + len - 1;

  /* skip whitespace at front */
  while ( len > 0 && IS_SPACE( (unsigned char) *str) ) {
    ++str;
    --len;
  }

  /* trim at end */
  while (end > str && IS_SPACE( (unsigned char) *end) ) {
    end--;
    --len;
  }

  reply = newSVpvn_flags( str, len, SvUTF8(sv) );
  if ( SvTAINTED(sv) ) SvTAINTED_on(reply);
  return reply;
}

/*
 * _trim_inplace: remove leading and trailing whitespace from an SV
 * in place (no allocation).
 *
 * Returns the total number of whitespace bytes removed.
 * Uses sv_chop() to advance past leading whitespace efficiently,
 * and adjusts SvCUR for trailing whitespace.
 */
IV _trim_inplace( pTHX_ SV *sv ) {
  STRLEN len;
  char *str;
  char *end;
  STRLEN lead = 0;
  STRLEN trail = 0;

  SvPV_force_nolen(sv);
  str = SvPVX(sv);
  len = SvCUR(sv);

  if ( len == 0 )
    return 0;

  end = str + len - 1;

  /* count and skip leading whitespace */
  while ( lead < len && IS_SPACE( (unsigned char) str[lead] ) )
    ++lead;

  /* count trailing whitespace (don't go past the leading trim point) */
  while ( end > (str + lead) && IS_SPACE( (unsigned char) *end ) ) {
    --end;
    ++trail;
  }

  if ( lead == 0 && trail == 0 )
    return 0;

  /* trim trailing first (just shorten the string) */
  if ( trail ) {
    SvCUR_set(sv, len - trail);
    SvPVX(sv)[len - trail] = '\0';
  }

  /* trim leading via sv_chop (adjusts PVX pointer + OOK offset) */
  if ( lead )
    sv_chop(sv, SvPVX(sv) + lead);

  SvSETMAGIC(sv);
  return (IV)(lead + trail);
}


/*
 * _apply_fast_map: given a precomputed 256-byte table, apply it to src
 * and write the result into a new SV.  Handles both UTF-8 and non-UTF-8
 * inputs.  Propagates UTF-8 and taint flags.
 *
 * This is the inner loop shared by the ad-hoc fast path and compiled maps.
 */
static SV *_apply_fast_map( pTHX_ const char fast_map[256], const char *src, STRLEN len, int is_utf8, SV *sv ) {
  SV *reply;
  char *str;
  STRLEN i;

  reply = newSV( len + 1 );
  SvPOK_on(reply);
  str = SvPVX(reply);

  if ( !is_utf8 ) {
    for ( i = 0; i < len; ++i )
      str[i] = fast_map[(unsigned char) src[i]];

    str[len] = '\0';
    SvCUR_set(reply, len);
  } else {
    STRLEN out = 0;
    for ( i = 0; i < len; ++i, ++out ) {
      unsigned char c = (unsigned char) src[i];
      if ( c >= 0x80 ) {
        STRLEN seq_len = UTF8_SEQ_LEN(c);
        STRLEN k;
        if ( i + seq_len > len ) seq_len = len - i;
        for ( k = 0; k < seq_len; ++k )
          str[out + k] = src[i + k];
        i += seq_len - 1;
        out += seq_len - 1;
      } else {
        str[out] = fast_map[c];
      }
    }

    str[out] = '\0';
    SvCUR_set(reply, out);
  }

  if ( SvUTF8(sv) )
    SvUTF8_on(reply);
  if ( SvTAINTED(sv) )
    SvTAINTED_on(reply);
  return reply;
}

SV *_replace_str( pTHX_ SV *sv, SV *map ) {
  STRLEN len;
  char *src;
  STRLEN        i = 0;
  char     *ptr;
  char           *str;                      /* pointer into reply SV's buffer */
  STRLEN      str_size;                     /* start with input length + some padding */
  STRLEN   ix_newstr = 0;
  AV           *mapav;
  SV           *reply;
  SSize_t       map_top;                    /* highest valid index in the map */
  int           is_utf8;                    /* whether the input string is UTF-8 */

  /* Compiled map: skip AV iteration entirely */
  {
    const char *compiled = _is_compiled_map( aTHX_ map );
    if ( compiled ) {
      src = SvPV(sv, len);
      is_utf8 = SvUTF8(sv) ? 1 : 0;
      return _apply_fast_map( aTHX_ compiled, src, len, is_utf8, sv );
    }
  }

  if ( !map || SvTYPE(map) != SVt_RV || SvTYPE(SvRV(map)) != SVt_PVAV
    || AvFILL( SvRV(map) ) < 0
    ) {
      src = SvPV(sv, len);
      reply = newSVpvn_flags( src, len, SvUTF8(sv) ); /* no alteration */
      if ( SvTAINTED(sv) ) SvTAINTED_on(reply);
      return reply;
  }

  src = SvPV(sv, len);
  ptr = src;
  str_size = len + 64;

  mapav = (AV *)SvRV(map);
  SV **ary = AvARRAY(mapav);
  map_top = AvFILL(mapav);
  is_utf8 = SvUTF8(sv) ? 1 : 0;

  /*
   * Fast path: when every map entry is a 1:1 byte replacement (single-char
   * PV, IV 0-255, or identity), we precompute a 256-byte lookup table and
   * avoid per-byte SV type dispatch entirely.
   */
  {
    char fast_map[256];

    if ( _build_fast_map( aTHX_ fast_map, ary, map_top, is_utf8 ) )
      return _apply_fast_map( aTHX_ fast_map, src, len, is_utf8, sv );
  }
  /* end fast path — fall through to general path */

  /*
   * Allocate the reply SV up front and write directly into its buffer.
   * This avoids Newx + newSVpvn_flags + Safefree (one alloc + copy saved).
   */
  reply = newSV( str_size );
  SvPOK_on(reply);
  str = SvPVX(reply);

  for ( i = 0; i < len; ++i, ++ptr, ++ix_newstr ) {
    unsigned char c = (unsigned char) *ptr;
    int  ix = (int) c;

    /*
     * UTF-8 safety: when the input has the UTF-8 flag set,
     * multi-byte sequences (bytes >= 0x80) must be copied through
     * unchanged. We only apply the replacement map to ASCII bytes
     * (0x00-0x7F). This prevents corrupting multi-byte characters
     * whose continuation bytes might collide with map entries.
     */
    if ( is_utf8 && c >= 0x80 ) {
      STRLEN seq_len = UTF8_SEQ_LEN(c);

      /* clamp to remaining bytes to avoid overread on malformed input */
      if ( i + seq_len > len ) seq_len = len - i;

      /* ensure buffer has room */
      ENSURE_ROOM(reply, str, str_size, ix_newstr, seq_len);

      /* copy the entire multi-byte sequence */
      str[ix_newstr] = (char) c;
      {
        STRLEN k;
        for ( k = 1; k < seq_len; ++k ) {
          ++i; ++ptr; ++ix_newstr;
          str[ix_newstr] = *ptr;
        }
      }
      continue;
    }

    str[ix_newstr] = (char) c; /* default always performed... */
    if ( ix > map_top
      || !ary[ix]
      ) {
      continue;
    } else {
      SV *entry = ary[ix];
      if ( SvPOK( entry ) ) {
        STRLEN slen;
        char *replace;
        SV *downgraded = NULL;

        /*
         * Encoding normalization: when the map entry and the output
         * have different UTF-8 states, we must reconcile them.
         *
         * - UTF-8 entry + non-UTF-8 output: downgrade the entry so
         *   codepoints 0-255 become single Latin-1 bytes (matching
         *   Perl's tr/// behavior). Wide chars (>255) cause a croak.
         *
         * - Non-UTF-8 entry + UTF-8 output: upgrade the entry so
         *   bytes 128-255 become proper 2-byte UTF-8 sequences.
         */
        if ( !is_utf8 && SvUTF8( entry ) ) {
          downgraded = newSVsv( entry );
          if ( !sv_utf8_downgrade( downgraded, TRUE ) ) {
            SvREFCNT_dec( downgraded );
            SvREFCNT_dec( reply );
            croak("Char::Replace: map entry for byte %d contains a wide character"
                  " (>255) that cannot be used with a non-UTF-8 input string", ix);
          }
          replace = SvPV( downgraded, slen );
        } else if ( is_utf8 && !SvUTF8( entry ) ) {
          downgraded = newSVsv( entry );
          sv_utf8_upgrade( downgraded );
          replace = SvPV( downgraded, slen );
        } else {
          replace = SvPV( entry, slen );
        }

        if ( slen == 0  ) {
          --ix_newstr; /* undo the default write: delete the character */
          if ( downgraded ) SvREFCNT_dec( downgraded );
          continue;
        } else {
          STRLEN j;

          ENSURE_ROOM(reply, str, str_size, ix_newstr, slen);

          /* replace all characters except the last one, which avoids us to do a --ix_newstr after */
          for ( j = 0 ; j < slen - 1; ++j ) {
            str[ix_newstr++] = replace[j];
          }

          /* handle the last character */
          str[ix_newstr] = replace[j];
        }
        if ( downgraded ) SvREFCNT_dec( downgraded );
      } else if ( SvIOK( entry ) || SvNOK( entry ) ) {
        /* IV/NV support: treat the integer value as an ordinal (chr) */
        IV val = SvIV( entry );
        if ( val >= 0 && val <= 255 ) {
          str[ix_newstr] = (char) val;
        }
        /* out-of-range values: keep original character (already written) */
      } else if ( SvROK( entry ) && SvTYPE( SvRV( entry ) ) == SVt_PVCV ) {
        /* Code ref: call the sub with the character as argument */
        dSP;
        SV *arg;
        SV *result;
        I32 count;
        char ch_buf[2];

        ch_buf[0] = (char) c;
        ch_buf[1] = '\0';
        arg = sv_2mortal( newSVpvn( ch_buf, 1 ) );
        if ( is_utf8 )
          SvUTF8_on( arg );

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs( arg );
        PUTBACK;

        count = call_sv( SvRV( entry ), G_SCALAR | G_EVAL );

        SPAGAIN;

        if ( SvTRUE( ERRSV ) ) {
          /* Callback died: clean up the reply SV we allocated,
           * then re-throw so the caller sees the original error. */
          (void) POPs;
          PUTBACK;
          FREETMPS;
          LEAVE;
          SvREFCNT_dec(reply);
          croak_sv( ERRSV );
        }

        if ( count == 1 ) {
          result = POPs;
          if ( SvOK( result ) ) {
            STRLEN slen;
            char *replace;
            SV *normalized = NULL;

            /* Encoding normalization for coderef results */
            if ( !is_utf8 && SvUTF8( result ) ) {
              normalized = newSVsv( result );
              if ( !sv_utf8_downgrade( normalized, TRUE ) ) {
                SvREFCNT_dec( normalized );
                PUTBACK;
                FREETMPS;
                LEAVE;
                SvREFCNT_dec( reply );
                croak("Char::Replace: coderef for byte %d returned a wide character"
                      " (>255) that cannot be used with a non-UTF-8 input string", ix);
              }
              replace = SvPV( normalized, slen );
            } else if ( is_utf8 && !SvUTF8( result ) ) {
              normalized = newSVsv( result );
              sv_utf8_upgrade( normalized );
              replace = SvPV( normalized, slen );
            } else {
              replace = SvPV( result, slen );
            }

            if ( slen == 0 ) {
              --ix_newstr; /* delete the character */
            } else {
              STRLEN j;

              ENSURE_ROOM(reply, str, str_size, ix_newstr, slen);

              for ( j = 0; j < slen - 1; ++j )
                str[ix_newstr++] = replace[j];
              str[ix_newstr] = replace[j];
            }
            if ( normalized ) SvREFCNT_dec( normalized );
          }
          /* undef result: keep original (already written) */
        }

        PUTBACK;
        FREETMPS;
        LEAVE;
      } /* end - SvPOK / SvIOK / SvNOK / code ref */
    } /* end - map_top || AvARRAY */
  }

  str[ix_newstr] = '\0';
  SvCUR_set(reply, ix_newstr);
  if ( SvUTF8(sv) )
    SvUTF8_on(reply);
  if ( SvTAINTED(sv) )
    SvTAINTED_on(reply);

  return reply;
}

/*
 * _replace_inplace: modify the SV's string buffer directly.
 *
 * Only supports 1:1 byte replacements: each map entry must be either
 * undef (keep original), a single-character PV, or an IV/NV in 0-255.
 * Entries that would expand or delete characters cause a croak.
 *
 * Returns the number of bytes actually changed.
 * UTF-8 safe: multi-byte sequences (>= 0x80) are skipped.
 */
/*
 * _apply_fast_map_inplace: apply a precomputed 256-byte table to a writable
 * SV buffer in place.  Returns the number of bytes changed.
 */
static IV _apply_fast_map_inplace( pTHX_ const char fast_map[256], char *str, STRLEN len, int is_utf8, SV *sv ) {
  STRLEN i;
  IV count = 0;

  if ( !is_utf8 ) {
    for ( i = 0; i < len; ++i ) {
      char replacement = fast_map[(unsigned char) str[i]];
      if ( str[i] != replacement ) {
        str[i] = replacement;
        ++count;
      }
    }
  } else {
    for ( i = 0; i < len; ++i ) {
      unsigned char c = (unsigned char) str[i];
      if ( c >= 0x80 ) {
        STRLEN seq_len = UTF8_SEQ_LEN(c);
        if ( i + seq_len > len ) seq_len = len - i;
        i += seq_len - 1;
        continue;
      }
      {
        char replacement = fast_map[c];
        if ( str[i] != replacement ) {
          str[i] = replacement;
          ++count;
        }
      }
    }
  }

  if ( count )
    SvSETMAGIC(sv);
  return count;
}

IV _replace_inplace( pTHX_ SV *sv, SV *map ) {
  STRLEN len;
  char *str;
  STRLEN i;
  AV *mapav;
  SV **ary;
  SSize_t map_top;
  int is_utf8;
  IV count = 0;

  /* Compiled map: skip AV iteration entirely */
  {
    const char *compiled = _is_compiled_map( aTHX_ map );
    if ( compiled ) {
      SvPV_force_nolen(sv);
      str = SvPVX(sv);
      len = SvCUR(sv);
      is_utf8 = SvUTF8(sv) ? 1 : 0;
      return _apply_fast_map_inplace( aTHX_ compiled, str, len, is_utf8, sv );
    }
  }

  if ( !map || SvTYPE(map) != SVt_RV || SvTYPE(SvRV(map)) != SVt_PVAV
    || AvFILL( SvRV(map) ) < 0
    ) {
      return 0; /* no valid map, nothing to do */
  }

  /* make the SV writable (COW handling) */
  SvPV_force_nolen(sv);
  str = SvPVX(sv);
  len = SvCUR(sv);

  mapav = (AV *)SvRV(map);
  ary = AvARRAY(mapav);
  map_top = AvFILL(mapav);
  is_utf8 = SvUTF8(sv) ? 1 : 0;

  /*
   * Fast path: precompute a 256-byte lookup table.
   * Only valid when all map entries are 1:1 byte replacements.
   * Croaks on multi-char/empty entries are deferred to the general path.
   */
  {
    char fast_map[256];

    if ( _build_fast_map( aTHX_ fast_map, ary, map_top, is_utf8 ) )
      return _apply_fast_map_inplace( aTHX_ fast_map, str, len, is_utf8, sv );
  }
  /* end fast path */

  for ( i = 0; i < len; ++i ) {
    unsigned char c = (unsigned char) str[i];
    int ix = (int) c;

    /* UTF-8 safety: skip multi-byte sequences */
    if ( is_utf8 && c >= 0x80 ) {
      STRLEN seq_len = UTF8_SEQ_LEN(c);
      if ( i + seq_len > len ) seq_len = len - i;
      i += seq_len - 1; /* -1 because the loop increments */
      continue;
    }

    if ( ix > map_top || !ary[ix] )
      continue;

    {
      SV *entry = ary[ix];
      if ( SvPOK( entry ) ) {
        STRLEN slen;
        char *replace = SvPV( entry, slen );
        if ( slen == 1 ) {
          /* Encoding safety: a non-UTF-8 byte > 127 into a UTF-8 string
           * would require 2 bytes (expansion), which is not possible in-place. */
          if ( is_utf8 && !SvUTF8( entry ) && ((unsigned char)replace[0]) >= 0x80 ) {
            croak("replace_inplace: map entry for byte %d is a non-UTF-8 byte 0x%02X"
                  " that cannot be placed into a UTF-8 string in-place"
                  " (would require expansion; use replace() instead)",
                  ix, (unsigned char)replace[0]);
          }
          if ( str[i] != replace[0] ) {
            str[i] = replace[0];
            ++count;
          }
        } else if ( SvUTF8( entry ) && slen == 2 ) {
          /* UTF-8 encoded Latin-1 character: decode to single byte */
          STRLEN retlen;
          UV cp = utf8_to_uvchr_buf( (U8*)replace, (U8*)(replace + slen), &retlen );
          if ( cp <= 255 && retlen == slen ) {
            if ( is_utf8 && cp >= 0x80 ) {
              croak("replace_inplace: map entry for byte %d decodes to codepoint 0x%02X"
                    " which requires 2 bytes in UTF-8 (cannot replace in-place;"
                    " use replace() instead)", ix, (unsigned int)cp);
            }
            {
              char byte = (char) cp;
              if ( str[i] != byte ) {
                str[i] = byte;
                ++count;
              }
            }
          } else {
            croak("replace_inplace: map entry for byte %d contains a wide character"
                  " (>255) not representable as a single byte", ix);
          }
        } else {
          croak("replace_inplace: map entry for byte %d is a %"UVuf"-byte string"
                " (only single-char replacements allowed)", ix, (UV)slen);
        }
      } else if ( SvIOK( entry ) || SvNOK( entry ) ) {
        IV val = SvIV( entry );
        if ( val >= 0 && val <= 255 ) {
          if ( str[i] != (char) val ) {
            str[i] = (char) val;
            ++count;
          }
        }
        /* out-of-range: keep original */
      } else if ( SvROK( entry ) && SvTYPE( SvRV( entry ) ) == SVt_PVCV ) {
        croak("replace_inplace: map entry for byte %d is a code ref"
              " (not supported for in-place replacement; use replace() instead)", ix);
      }
    }
  }

  if ( count )
    SvSETMAGIC(sv);
  return count;
}

MODULE = Char__Replace       PACKAGE = Char::Replace

PROTOTYPES: DISABLE

SV*
replace(sv, map)
  SV *sv;
  SV *map;
CODE:
  if ( sv && (SvOK(sv) || SvMAGICAL(sv)) && (!SvROK(sv) || SvAMAGIC(sv)) ) {
     RETVAL = _replace_str( aTHX_ sv, map );
  } else {
     RETVAL = &PL_sv_undef;
  }
OUTPUT:
  RETVAL

SV*
trim(sv)
  SV *sv;
CODE:
  if ( sv && (SvOK(sv) || SvMAGICAL(sv)) && (!SvROK(sv) || SvAMAGIC(sv)) ) {
     RETVAL = _trim_sv( aTHX_ sv );
  } else {
     RETVAL = &PL_sv_undef;
  }
OUTPUT:
  RETVAL

IV
replace_inplace(sv, map)
  SV *sv;
  SV *map;
CODE:
  if ( sv && (SvOK(sv) || SvMAGICAL(sv)) && (!SvROK(sv) || SvAMAGIC(sv)) ) {
     RETVAL = _replace_inplace( aTHX_ sv, map );
  } else {
     RETVAL = 0;
  }
OUTPUT:
  RETVAL

IV
trim_inplace(sv)
  SV *sv;
CODE:
  if ( sv && (SvOK(sv) || SvMAGICAL(sv)) && (!SvROK(sv) || SvAMAGIC(sv)) ) {
     RETVAL = _trim_inplace( aTHX_ sv );
  } else {
     RETVAL = 0;
  }
OUTPUT:
  RETVAL

SV*
identity_map()
CODE:
{
  AV *av = newAV();
  int i;
  char buf[2];

  av_extend(av, 255);
  buf[1] = '\0';
  for ( i = 0; i <= 255; ++i ) {
    buf[0] = (char) i;
    av_store( av, i, newSVpvn( buf, 1 ) );
  }
  RETVAL = newRV_noinc( (SV *) av );
}
OUTPUT:
  RETVAL

SV*
compile_map(map)
  SV *map;
CODE:
{
  AV *mapav;
  SV **ary;
  SSize_t map_top;
  char fast_map[256];
  SV *inner;

  if ( !map || !SvROK(map) || SvTYPE(SvRV(map)) != SVt_PVAV
    || AvFILL( (AV *)SvRV(map) ) < 0
    ) {
      croak("compile_map: argument must be a non-empty array ref");
  }

  mapav = (AV *)SvRV(map);
  ary = AvARRAY(mapav);
  map_top = AvFILL(mapav);

  /*
   * Build the fast map with is_utf8=0.  This is the conservative choice:
   * entries with high bytes are decoded from UTF-8 to Latin-1 if possible.
   * At runtime, the same table works for both UTF-8 and non-UTF-8 inputs
   * because bytes >= 0x80 are identity-mapped and multi-byte sequences
   * are skipped in UTF-8 mode.
   *
   * If any entry is not fast-path eligible (multi-char, coderef, deletion),
   * we croak — compile_map only supports 1:1 byte maps.
   */
  if ( !_build_fast_map( aTHX_ fast_map, ary, map_top, 0 ) ) {
    croak("compile_map: map contains entries not eligible for compilation"
          " (multi-char strings, empty strings, code refs, or wide characters);"
          " use the array ref directly with replace() for these maps");
  }

  /* Store the 256-byte table in a PV SV, blessed into CompiledMap */
  inner = newSVpvn( fast_map, 256 );
  RETVAL = sv_bless( newRV_noinc(inner),
                     gv_stashpvn( COMPILED_MAP_CLASS,
                                  sizeof(COMPILED_MAP_CLASS) - 1, GV_ADD ) );
}
OUTPUT:
  RETVAL
