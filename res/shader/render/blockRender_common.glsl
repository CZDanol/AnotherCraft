#if (ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST || ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST_GLOW) && MSAA_ALPHA_TEST
	#define UV_QUALIFIERS sample
#else
	#define UV_QUALIFIERS
#endif