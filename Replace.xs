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

SV *_replace_str( SV *sv, SV *map );
SV *_trim_sv( SV *sv );
IV _replace_inplace( SV *sv, SV *map );

/*
 * _build_fast_map: populate a 256-byte identity lookup table, then
 * overwrite entries according to the Perl map array.
 *
 * Returns 1 if every map entry is a 1:1 byte replacement (fast-path
 * eligible).  Returns 0 if any entry requires expansion, deletion,
 * or is otherwise incompatible — the caller should fall through to
 * the general path.
 */
static int _build_fast_map( char fast_map[256], SV **ary, SSize_t map_top ) {
  dTHX;
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
        fast_map[ix] = pv[0];
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
    /* undef/other: identity (already set) */
  }
  return 1;
}

SV *_trim_sv( SV *sv ) {
  dTHX;
  STRLEN len  = SvCUR(sv);
  char *str = SvPVX(sv);
  char *end;

  if ( len == 0 )
    return newSVpvn_flags( str, 0, SvUTF8(sv) );

  end = str + len - 1;

  // Skip whitespace at front...
  while ( len > 0 && IS_SPACE( (unsigned char) *str) ) {
    ++str;
    --len;
  }

  // Trim at end...
  while (end > str && IS_SPACE( (unsigned char) *end) ) {
    end--;
    --len;
  }

  return newSVpvn_flags( str, len, SvUTF8(sv) );
}


SV *_replace_str( SV *sv, SV *map ) {
  dTHX;
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

  if ( !map || SvTYPE(map) != SVt_RV || SvTYPE(SvRV(map)) != SVt_PVAV
    || AvFILL( SvRV(map) ) < 0
    ) {
      src = SvPV(sv, len);
      return newSVpvn_flags( src, len, SvUTF8(sv) ); /* no alteration */
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

    if ( _build_fast_map( fast_map, ary, map_top ) ) {
      reply = newSV( len + 1 );
      SvPOK_on(reply);
      str = SvPVX(reply);

      if ( !is_utf8 ) {
        /* tight loop: no SV dispatch, no UTF-8 checks */
        for ( i = 0; i < len; ++i )
          str[i] = fast_map[(unsigned char) src[i]];

        str[len] = '\0';
        SvCUR_set(reply, len);
      } else {
        /* UTF-8 aware fast path: use table for ASCII, copy multi-byte sequences */
        STRLEN out = 0;
        for ( i = 0; i < len; ++i, ++out ) {
          unsigned char c = (unsigned char) src[i];
          if ( c >= 0x80 ) {
            STRLEN seq_len = UTF8_SEQ_LEN(c);
            STRLEN k;
            if ( i + seq_len > len ) seq_len = len - i;
            for ( k = 0; k < seq_len; ++k )
              str[out + k] = src[i + k];
            i += seq_len - 1;    /* -1: loop increments */
            out += seq_len - 1;  /* -1: loop increments */
          } else {
            str[out] = fast_map[c];
          }
        }

        str[out] = '\0';
        SvCUR_set(reply, out);
      }

      if ( SvUTF8(sv) )
        SvUTF8_on(reply);
      return reply;
    }
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
      if ( str_size <= (ix_newstr + seq_len + 1) ) {
        while ( str_size <= (ix_newstr + seq_len + 1) )
          str_size *= 2;
        SvGROW( reply, str_size );
        str = SvPVX(reply);
      }

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
        char *replace = SvPV( entry, slen ); /* length of the string used for replacement */
        if ( slen == 0  ) {
          --ix_newstr; /* undo the default write: delete the character */
          continue;
        } else {
          STRLEN j;

          /* Check if we need to expand. */
          if (str_size <= (ix_newstr + slen + 1) ) { /* +1 for \0 */
            while (str_size <= (ix_newstr + slen + 1)) {
              str_size *= 2;
            }
            SvGROW( reply, str_size );
            str = SvPVX(reply);
          }

          /* replace all characters except the last one, which avoids us to do a --ix_newstr after */
          for ( j = 0 ; j < slen - 1; ++j ) {
            str[ix_newstr++] = replace[j];
          }

          /* handle the last character */
          str[ix_newstr] = replace[j];
        }
      } else if ( SvIOK( entry ) || SvNOK( entry ) ) {
        /* IV/NV support: treat the integer value as an ordinal (chr) */
        IV val = SvIV( entry );
        if ( val >= 0 && val <= 255 ) {
          str[ix_newstr] = (char) val;
        }
        /* out-of-range values: keep original character (already written) */
      } /* end - SvPOK / SvIOK / SvNOK */
    } /* end - map_top || AvARRAY */
  }

  str[ix_newstr] = '\0';
  SvCUR_set(reply, ix_newstr);
  if ( SvUTF8(sv) )
    SvUTF8_on(reply);

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
IV _replace_inplace( SV *sv, SV *map ) {
  dTHX;
  STRLEN len;
  char *str;
  STRLEN i;
  AV *mapav;
  SV **ary;
  SSize_t map_top;
  int is_utf8;
  IV count = 0;

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

    if ( _build_fast_map( fast_map, ary, map_top ) ) {
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
          if ( str[i] != replace[0] ) {
            str[i] = replace[0];
            ++count;
          }
        } else {
          croak("replace_inplace: map entry for byte %d is a %"UVuf"-char string"
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
      }
    }
  }

  if ( count )
    SvSETMAGIC(sv);
  return count;
}

MODULE = Char__Replace       PACKAGE = Char::Replace

SV*
replace(sv, map)
  SV *sv;
  SV *map;
CODE:
  if ( sv && SvPOK(sv) ) {
     RETVAL = _replace_str( sv, map );
  } else {
     RETVAL = &PL_sv_undef;
  }
OUTPUT:
  RETVAL

SV*
trim(sv)
  SV *sv;
CODE:
  if ( sv && SvPOK(sv) ) {
     RETVAL = _trim_sv( sv );
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
  if ( sv && SvPOK(sv) ) {
     RETVAL = _replace_inplace( sv, map );
  } else {
     RETVAL = 0;
  }
OUTPUT:
  RETVAL
