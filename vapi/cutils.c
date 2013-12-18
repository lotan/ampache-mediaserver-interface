#include "cutils.h"

static inline gboolean
_esc_ident_bad (gchar c, gboolean is_first)
{
  return ((c < 'a' || c > 'z') &&
          (c < 'A' || c > 'Z') &&
          (c < '0' || c > '9' || is_first));
}


/**
 * escape_as_identifier:
 * @name: The string to be escaped
 *
 * Escape an arbitrary string so it follows the rules for a C identifier,
 * and hence an object path component, interface element component,
 * bus name component or member name in D-Bus.
 *
 * Unlike g_strcanon this is a reversible encoding, so it preserves
 * distinctness.
 *
 * The escaping consists of replacing all non-alphanumerics, and the first
 * character if it's a digit, with an underscore and two lower-case hex
 * digits:
 *
 *    "0123abc_xyz\x01\xff" -> _30123abc_5fxyz_01_ff
 *
 * i.e. similar to URI encoding, but with _ taking the role of %, and a
 * smaller allowed set. As a special case, "" is escaped to "_" (just for
 * completeness, really).
 *
 * Returns: the escaped string, which must be freed by the caller with #g_free
 */
gchar *
escape_as_identifier (const gchar *name)
{
  gboolean bad = FALSE;
  size_t len = 0;
  GString *op;
  const gchar *ptr, *first_ok;

  g_return_val_if_fail (name != NULL, NULL);

  /* fast path for empty name */
  if (name[0] == '\0')
    return g_strdup ("_");

  for (ptr = name; *ptr; ptr++)
    {
      if (_esc_ident_bad (*ptr, ptr == name))
        {
          bad = TRUE;
          len += 3;
        }
      else
        len++;
    }

  /* fast path if it's clean */
  if (!bad)
    return g_strdup (name);

  /* If strictly less than ptr, first_ok is the first uncopied safe character.
   */
  first_ok = name;
  op = g_string_sized_new (len);
  for (ptr = name; *ptr; ptr++)
    {
      if (_esc_ident_bad (*ptr, ptr == name))
        {
          /* copy preceding safe characters if any */
          if (first_ok < ptr)
            {
              g_string_append_len (op, first_ok, ptr - first_ok);
            }
          /* escape the unsafe character */
          g_string_append_printf (op, "_%02x", (unsigned char)(*ptr));
          /* restart after it */
          first_ok = ptr + 1;
        }
    }
  /* copy trailing safe characters if any */
  if (first_ok < ptr)
    {
      g_string_append_len (op, first_ok, ptr - first_ok);
    }
  return g_string_free (op, FALSE);
}
