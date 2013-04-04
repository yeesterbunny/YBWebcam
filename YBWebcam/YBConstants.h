
#define YBHeader_Length         8

#define SERVICE_NAME                @"YBWEBCAM"
#define INPUT_BUFFER_SIZE           10000
#define YB_HEADER                   0x7777777
#define CAMERAVIEWDIDCLOSE          @"cameraViewDidClose"

typedef struct _ybheader{
    uint32_t ybHeader;
    uint32_t imageDataLength;
} __attribute__ ((packed)) YBHeader;