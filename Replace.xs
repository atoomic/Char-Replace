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

SV *_replace_str( SV *sv, SV *map );
SV *_trim_sv( SV *sv );
IV _replace_inplace( SV *sv, SV *map );

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
  char           *str;                      /* the new string we are going to use */
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

  /* Always allocate memory using Perl's memory management */
  Newx(str, str_size, char);

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
      STRLEN seq_len = 1;
      if      ( c >= 0xFC ) seq_len = 6;
      else if ( c >= 0xF8 ) seq_len = 5;
      else if ( c >= 0xF0 ) seq_len = 4;
      else if ( c >= 0xE0 ) seq_len = 3;
      else if ( c >= 0xC0 ) seq_len = 2;
      /* else: continuation byte (0x80-0xBF) — copy as-is, seq_len=1 */

      /* clamp to remaining bytes to avoid overread on malformed input */
      if ( i + seq_len > len ) seq_len = len - i;

      /* ensure buffer has room */
      if ( str_size <= (ix_newstr + seq_len + 1) ) {
        while ( str_size <= (ix_newstr + seq_len + 1) )
          str_size *= 2;
        Renew( str, str_size, char );
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
            /* Calculate the required size, ensuring it's enough */
            while (str_size <= (ix_newstr + slen + 1)) {
              str_size *= 2;
            }
            /* grow the string */
            Renew( str, str_size, char );
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

  str[ix_newstr] = '\0'; /* add the final trailing \0 character */

  reply = newSVpvn_flags( str, ix_newstr, SvUTF8(sv) );

  /* free our tmp buffer */
  Safefree(str);

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

  for ( i = 0; i < len; ++i ) {
    unsigned char c = (unsigned char) str[i];
    int ix = (int) c;

    /* UTF-8 safety: skip multi-byte sequences */
    if ( is_utf8 && c >= 0x80 ) {
      STRLEN seq_len = 1;
      if      ( c >= 0xFC ) seq_len = 6;
      else if ( c >= 0xF8 ) seq_len = 5;
      else if ( c >= 0xF0 ) seq_len = 4;
      else if ( c >= 0xE0 ) seq_len = 3;
      else if ( c >= 0xC0 ) seq_len = 2;
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
