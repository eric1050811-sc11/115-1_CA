#=========================================================================
# Modular C++ Build System Subproject Makefile Fragment
#=========================================================================
# Please read the documenation in 'mcppbs-uguide.txt' for more details
# on how the Modular C++ Build System works.

ubmark_intdeps  = 
ubmark_cppflags = -I../ubmark 
ubmark_ldflags  = 
ubmark_libs     = -lubmark 

ubmark_hdrs = \
  ubmark.h \

ubmark_srcs = crt0.S \

# Keep the published public benchmark binary identical to the calibration
# build, which used -O3 without the suite-wide -funroll-loops option.
ubmark-cache-public.o: COMPILE_C := \
  $(CC) $(CFLAGS) -MMD -MP -I. $(CPPFLAGS)

ubmark_install_prog_srcs = \
  ubmark-vvadd.c \
  ubmark-cmplx-mult.c \
  ubmark-bin-search.c \
  ubmark-masked-filter.c \
  ubmark-cache-public.c \
