#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

#include "comp.h"

void cputc(char ch)
{
   if (ch == '\n')
   {
      pos_x = 0;
      newline();
   }
   else
   {
      putchar(ch);
      pos_x++;

      // End of line, just start at next line
      if (pos_x >= H_CHARS)
      {
         pos_x = 0;
         newline();
      }
   }
} // end of cputc
