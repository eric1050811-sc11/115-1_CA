//========================================================================
// ubmark-cache-public
//========================================================================
// Apply a lookup-table correction while combining two sensor vectors.

#include "ubmark.h"

typedef unsigned int uint32_t;

enum {
  kSamples = 8192,
  kSamplesPerFrame = 16,
  kFrames = kSamples/kSamplesPerFrame,
  kCorrectionEntries = 256,
  kPasses = 2
};

static uint32_t sensor_a[kSamples] __attribute__((aligned(64)));
static uint32_t sensor_b[kSamples] __attribute__((aligned(64)));
static uint32_t output[kSamples] __attribute__((aligned(64)));
static uint32_t correction[kCorrectionEntries]
  __attribute__((aligned(64)));

__attribute__((noinline))
void apply_correction( uint32_t* dest,
                       const uint32_t* src_a,
                       const uint32_t* src_b,
                       const uint32_t* table )
{
  int pass;
  int frame;
  int sample;

  for ( pass = 0; pass < kPasses; pass++ ) {
    for ( frame = 0; frame < kFrames; frame++ ) {
      // Samples arrive oldest-to-newest, but the newest sample in each frame
      // is processed first.
      for ( sample = kSamplesPerFrame-1; sample >= 0; sample-- ) {
        int i = frame*kSamplesPerFrame+sample;
        dest[i] = src_a[i] + src_b[i]
                  + table[i % kCorrectionEntries];
      }
    }
  }
}

int main( int argc, char* argv[] )
{
  uint32_t checksum = 0;
  int temp = 0;
  int i;

  for ( i = 0; i < kSamples; i++ ) {
    sensor_a[i] = 1;
    sensor_b[i] = 1;
    output[i] = 0;
  }

  for ( i = 0; i < kCorrectionEntries; i++ )
    correction[i] = 1;

  test_stats_on( temp );
  apply_correction(output, sensor_a, sensor_b, correction);
  for ( i = 0; i < kSamples; i++ )
    checksum += output[i];
  test_stats_off( temp );

  if ( checksum != 3*kSamples )
    test_fail( temp );

  test_pass( temp );
  return 0;
}
