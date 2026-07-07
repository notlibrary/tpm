AC_INIT([tpm],0.7.1, [yendorium@gmail.com])
AM_INIT_AUTOMAKE([foreign subdir-objects])
AC_PROG_CC

AC_SEARCH_LIBS([gettext], [intl], [], [
   AC_MSG_ERROR([gettext function or libintl not found!])
])

AC_CHECK_HEADERS([libintl.h], [], [
   AC_MSG_ERROR([libintl.h header file is missing!])
])

AC_CHECK_HEADERS([locale.h])


AC_CONFIG_HEADERS([src/config.h])

AC_CHECK_HEADERS([getopt.h])
AC_CHECK_FUNCS([getopt getopt_long])

AC_CONFIG_FILES([
 Makefile
 src/Makefile
 tests/Makefile
])

AC_OUTPUT