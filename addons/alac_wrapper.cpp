/*****************************************************************************
 * audio_stream.c: audio file stream
 *
 * Copyright (C) 2005 Shiro Ninomiya <shiron@snino.com>
 *				 2016 Philippe <philippe_44@outlook.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111, USA.
 *****************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ALACEncoder.h"
#include "ALACDecoder.h"
#include "ALACBitUtilities.h"

#include "alac_wrapper.h"

#include <atomic>

#define min(a,b) (((a) < (b)) ? (a) : (b))
#define max(a,b) (((a) > (b)) ? (a) : (b))

typedef struct alac_codec_s {
	AudioFormatDescription inputFormat, outputFormat;
	ALACEncoder *encoder;
	ALACDecoder *Decoder;
	unsigned block_size, frames_per_packet;
} alac_codec_t;

/*----------------------------------------------------------------------------*/
extern "C" struct alac_codec_s *alac_create_decoder(int magic_cookie_size, unsigned char *magic_cookie,
											unsigned char *sample_size, unsigned *sample_rate,
											unsigned char *channels, unsigned int *block_size) {
	struct alac_codec_s *codec = (struct alac_codec_s*) malloc(sizeof(struct alac_codec_s));

	codec->Decoder = new ALACDecoder;
	codec->Decoder->Init(magic_cookie, magic_cookie_size);

	*channels = codec->Decoder->mConfig.numChannels;
	*sample_rate = codec->Decoder->mConfig.sampleRate;
	*sample_size = codec->Decoder->mConfig.bitDepth;

	codec->frames_per_packet = codec->Decoder->mConfig.frameLength;
	*block_size = codec->block_size = codec->frames_per_packet * (*channels) * (*sample_size) / 8;

	return codec;
}

/*----------------------------------------------------------------------------*/
extern "C" void alac_delete_decoder(struct alac_codec_s *codec) {
	delete (ALACDecoder*) codec->Decoder;
	free(codec);
}

/*----------------------------------------------------------------------------*/

extern "C" bool alac_to_pcm(struct alac_codec_s *codec, unsigned char* input,
							unsigned char *output, char channels, unsigned *out_frames) {
	BitBuffer input_buffer;

	BitBufferInit(&input_buffer, input, codec->block_size);
	return codec->Decoder->Decode(&input_buffer, output, codec->frames_per_packet, channels, out_frames) == ALAC_noErr;

}

/*----------------------------------------------------------------------------*/
// assumes stereo and little endian
extern "C" bool pcm_to_alac_raw(uint8_t *sample, int frames, uint8_t **out, int *size, int bsize) {
	uint8_t *p;
	uint32_t *in = (uint32_t*) sample;
	int count;

	frames = min(frames, bsize);

	*out = (uint8_t*) malloc(bsize * 4 + 16);
	p = *out;

	*p++ = (1 << 5);
	*p++ = 0;
	*p++ = (1 << 4) | (1 << 1) | ((bsize & 0x80000000) >> 31); // b31
	*p++ = ((bsize & 0x7f800000) << 1) >> 24;	// b30--b23
	*p++ = ((bsize & 0x007f8000) << 1) >> 16;	// b22--b15
	*p++ = ((bsize & 0x00007f80) << 1) >> 8;	// b14--b7
	*p =   ((bsize & 0x0000007f) << 1);       	// b6--b0
	*p++ |= (*in &  0x00008000) >> 15;			// LB1 b7

	count = frames - 1;

	while (count--) {
		// LB1 b6--b0 + LB0 b7
		*p++ = ((*in & 0x00007f80) >> 7);
		// LB0 b6--b0 + RB1 b7
		*p++ = ((*in & 0x0000007f) << 1) | ((*in & 0x80000000) >> 31);
		// RB1 b6--b0 + RB0 b7
		*p++ = ((*in & 0x7f800000) >> 23);
		// RB0 b6--b0 + next LB1 b7
		*p++ = ((*in & 0x007f0000) >> 15) | ((*(in + 1) & 0x00008000) >> 15);

		in++;
	}

	// last sample
	// LB1 b6--b0 + LB0 b7
	*p++ = ((*in & 0x00007f80) >> 7);
	// LB0 b6--b0 + RB1 b7
	*p++ = ((*in & 0x0000007f) << 1) | ((*in & 0x80000000) >> 31);
	// RB1 b6--b0 + RB0 b7
	*p++ = ((*in & 0x7f800000) >> 23);
	// RB0 b6--b0 + next LB1 b7
	*p++ = ((*in & 0x007f0000) >> 15);

	// when readable size is less than bsize, fill 0 at the bottom
	count = (bsize - frames) * 4;
	while (count--)	*p++ = 0;

	// frame footer ??
	*(p-1) |= 1;
	*p = (7 >> 1) << 6;

	*size = p - *out + 1;

	return true;
}

/*----------------------------------------------------------------------------*/
// assumes stereo and little endian
extern "C" bool pcm_to_alac(struct alac_codec_s *codec, uint8_t *in, int frames, uint8_t **out, int *size) {
	// can't encode more than configured
	if (frames > (int)codec->outputFormat.mFramesPerPacket) {
		*size = 0;
		*out = NULL;
		return false;
	}

	// ALAC might have bug and creates more data than expected (or allocaed buffer should be zero'd)
	*size = codec->outputFormat.mFramesPerPacket * codec->inputFormat.mBytesPerFrame;
	*out = (uint8_t*)calloc(*size + kALACMaxEscapeHeaderBytes + 64, 1);
	return !codec->encoder->Encode(codec->inputFormat, codec->outputFormat, in, *out, size);
}

#define kTestFormatFlag_16BitSourceData 1

/*----------------------------------------------------------------------------*/
extern "C" struct alac_codec_s *alac_create_encoder(int max_frames, int sample_rate, int sample_size, int channels) {
	alac_codec_t *codec;

	if ((codec = (alac_codec_t*) malloc(sizeof(alac_codec_t))) == NULL) return NULL;

	if ((codec->encoder = new ALACEncoder) == NULL) {
		free(codec);
		return NULL;
	}

	// input format is pretty much dictated
	codec->inputFormat.mFormatID = kALACFormatLinearPCM;
	codec->inputFormat.mSampleRate = sample_rate;
	codec->inputFormat.mBitsPerChannel = sample_size;
	codec->inputFormat.mFramesPerPacket = 1;
	codec->inputFormat.mChannelsPerFrame = channels;
	codec->inputFormat.mBytesPerFrame = codec->inputFormat.mChannelsPerFrame * codec->inputFormat.mFramesPerPacket * (codec->inputFormat.mBitsPerChannel / 8);
	codec->inputFormat.mBytesPerPacket = codec->inputFormat.mBytesPerFrame * codec->inputFormat.mFramesPerPacket;
	codec->inputFormat.mFormatFlags = kALACFormatFlagsNativeEndian | kALACFormatFlagIsSignedInteger; // expect signed native-endian data
	codec->inputFormat.mReserved = 0;

	// and so is the output format
	codec->outputFormat.mFormatID = kALACFormatAppleLossless;
	codec->outputFormat.mSampleRate = codec->inputFormat.mSampleRate;
	codec->outputFormat.mFormatFlags = kTestFormatFlag_16BitSourceData;
	codec->outputFormat.mFramesPerPacket = max_frames;
	codec->outputFormat.mChannelsPerFrame = codec->inputFormat.mChannelsPerFrame;
	codec->outputFormat.mBytesPerPacket = 0; // we're VBR
	codec->outputFormat.mBytesPerFrame = 0; // same
	codec->outputFormat.mBitsPerChannel = 0; // each bit doesn't really go with 1 sample
	codec->outputFormat.mReserved = 0;

	codec->encoder->SetFrameSize(codec->outputFormat.mFramesPerPacket);
	codec->encoder->SetFastMode(true);
	codec->encoder->InitializeEncoder(codec->outputFormat);

	return codec;
}

/*----------------------------------------------------------------------------*/
extern "C" void alac_delete_encoder(struct alac_codec_s *codec) {
	delete codec->encoder;
	free(codec);
}



