
#define YBHeader_Length         8

typedef struct _ybheader{
    uint32_t ybHeader;
    uint32_t imageDataLength;
} __attribute__ ((packed)) YBHeader;