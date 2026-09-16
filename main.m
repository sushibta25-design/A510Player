#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <unistd.h>

static NSString * const kHost = @"192.168.0.1";
static const int kPort = 554;
static NSString * const kStartURL = @"rtsp://192.168.0.1:554/livestream/12";
static NSString * const kLogPath = @"/var/mobile/A510Player.log";

static void Log(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [s stringByAppendingString:@"\n"];
    NSData *d = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:kLogPath]) [d writeToFile:kLogPath atomically:YES];
    else {
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        [h seekToEndOfFile]; [h writeData:d]; [h closeFile];
    }
}

static BOOL SendAll(int fd, NSData *d) {
    const uint8_t *p=d.bytes; size_t left=d.length;
    while(left){ ssize_t n=send(fd,p,left,0); if(n<=0)return NO; p+=n; left-=n; }
    return YES;
}

static NSString *ReadRTSP(int fd, NSMutableData *carry) {
    while (1) {
        const uint8_t *b=carry.bytes; NSUInteger n=carry.length;
        for(NSUInteger i=3;i<n;i++){
            if(b[i-3]=='\r'&&b[i-2]=='\n'&&b[i-1]=='\r'&&b[i]=='\n'){
                NSUInteger headerEnd=i+1;
                NSData *hd=[carry subdataWithRange:NSMakeRange(0,headerEnd)];
                NSString *hs=[[NSString alloc] initWithData:hd encoding:NSUTF8StringEncoding];
                NSInteger cl=0;
                NSRange r=[hs rangeOfString:@"Content-Length:" options:NSCaseInsensitiveSearch];
                if(r.location!=NSNotFound){
                    NSString *tail=[hs substringFromIndex:NSMaxRange(r)];
                    cl=[[tail componentsSeparatedByString:@"\r\n"].firstObject integerValue];
                }
                NSUInteger total=headerEnd+(NSUInteger)MAX(cl,0);
                if(carry.length>=total){
                    NSData *all=[carry subdataWithRange:NSMakeRange(0,total)];
                    [carry replaceBytesInRange:NSMakeRange(0,total) withBytes:NULL length:0];
                    return [[NSString alloc] initWithData:all encoding:NSUTF8StringEncoding];
                }
            }
        }
        uint8_t tmp[8192]; ssize_t got=recv(fd,tmp,sizeof(tmp),0);
        if(got<=0)return nil;
        [carry appendBytes:tmp length:(NSUInteger)got];
    }
}

static NSString *Header(NSString *resp, NSString *name) {
    for(NSString *line in [resp componentsSeparatedByString:@"\r\n"]){
        NSRange r=[line rangeOfString:[name stringByAppendingString:@":"] options:NSCaseInsensitiveSearch];
        if(r.location==0) return [[line substringFromIndex:NSMaxRange(r)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return nil;
}

static NSString *Request(NSString *method, NSString *url, int cseq, NSString *extra) {
    return [NSString stringWithFormat:@"%@ %@ RTSP/1.0\r\nCSeq: %d\r\nUser-Agent: A510Player-Stage2-v2\r\n%@\r\n",
            method,url,cseq,extra ?: @""];
}

int main(int argc, char **argv) {
 @autoreleasepool {
    [[NSFileManager defaultManager] removeItemAtPath:kLogPath error:nil];
    Log(@"=== A510 PLAYER STAGE 2 V2 ===");

    int fd=socket(AF_INET,SOCK_STREAM,0);
    struct timeval tv={5,0};
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));
    struct sockaddr_in a={0}; a.sin_family=AF_INET; a.sin_port=htons(kPort);
    inet_pton(AF_INET,kHost.UTF8String,&a.sin_addr);
    if(connect(fd,(struct sockaddr*)&a,sizeof(a))!=0){ Log(@"CONNECT FAILED"); return 2; }
    Log(@"CONNECTED %@:%d",kHost,kPort);

    NSMutableData *carry=[NSMutableData data];
    int cseq=1;

    NSString *q=Request(@"OPTIONS",kStartURL,cseq++,@"");
    SendAll(fd,[q dataUsingEncoding:NSUTF8StringEncoding]);
    NSString *resp=ReadRTSP(fd,carry); Log(@"OPTIONS RESPONSE:\n%@",resp ?: @"(nil)");

    q=Request(@"DESCRIBE",kStartURL,cseq++,@"Accept: application/sdp\r\n");
    SendAll(fd,[q dataUsingEncoding:NSUTF8StringEncoding]);
    resp=ReadRTSP(fd,carry); Log(@"DESCRIBE RESPONSE:\n%@",resp ?: @"(nil)");
    if(!resp){ close(fd); return 3; }

    NSString *base=Header(resp,@"Content-Base");
    if(!base.length) base=@"rtsp://192.168.0.1/00000000/";
    NSString *track=[base stringByAppendingString:@"track1"];
    Log(@"CONTENT_BASE=%@",base);
    Log(@"TRACK_URL=%@",track);

    NSString *transport=@"Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n";
    q=Request(@"SETUP",track,cseq++,transport);
    Log(@"SETUP REQUEST:\n%@",q);
    SendAll(fd,[q dataUsingEncoding:NSUTF8StringEncoding]);
    resp=ReadRTSP(fd,carry);
    Log(@"SETUP RESPONSE:\n%@",resp ?: @"(nil)");
    NSString *session=Header(resp ?: @"",@"Session");
    if([session containsString:@";"]) session=[session componentsSeparatedByString:@";"].firstObject;
    Log(@"SESSION=%@",session ?: @"(nil)");
    if(!session.length){ close(fd); return 4; }

    NSString *playExtra=[NSString stringWithFormat:@"Session: %@\r\nRange: npt=0.000-\r\n",session];
    q=Request(@"PLAY",base,cseq++,playExtra);
    Log(@"PLAY REQUEST:\n%@",q);
    SendAll(fd,[q dataUsingEncoding:NSUTF8StringEncoding]);
    resp=ReadRTSP(fd,carry);
    Log(@"PLAY RESPONSE:\n%@",resp ?: @"(nil)");

    tv.tv_sec=15; tv.tv_usec=0;
    setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));

    NSUInteger packets=0, rtpBytes=0, h264Payloads=0;
    NSMutableData *stream=[NSMutableData dataWithData:carry];
    [carry setLength:0];

    while(1){
        while(stream.length>=4){
            const uint8_t *b=stream.bytes;
            if(b[0]!='$'){ [stream replaceBytesInRange:NSMakeRange(0,1) withBytes:NULL length:0]; continue; }
            uint16_t L=((uint16_t)b[2]<<8)|b[3];
            if(stream.length < (NSUInteger)(4+L)) break;
            uint8_t channel=b[1];
            NSData *pkt=[stream subdataWithRange:NSMakeRange(4,L)];
            if(channel==0 && L>=12){
                packets++; rtpBytes+=L;
                const uint8_t *r=pkt.bytes;
                NSUInteger cc=r[0]&0x0F;
                NSUInteger off=12+cc*4;
                if((r[0]&0x10) && L>=off+4){
                    NSUInteger ext=((NSUInteger)r[off+2]<<8)|r[off+3];
                    off+=4+ext*4;
                }
                if(off<L){
                    h264Payloads++;
                    uint8_t nal=r[off]&0x1F;
                    if(packets<=10 || nal==5 || nal==7 || nal==8)
                        Log(@"RTP PACKET #%lu bytes=%u H264_NAL=%u",(unsigned long)packets,L,nal);
                }
            }
            [stream replaceBytesInRange:NSMakeRange(0,4+L) withBytes:NULL length:0];
        }
        uint8_t tmp[65536]; ssize_t n=recv(fd,tmp,sizeof(tmp),0);
        if(n<=0) break;
        [stream appendBytes:tmp length:(NSUInteger)n];
    }

    Log(@"RTP SUMMARY packets=%lu rtpBytes=%lu h264Payloads=%lu",
        (unsigned long)packets,(unsigned long)rtpBytes,(unsigned long)h264Payloads);
    Log(@"=== STAGE 2 V2 END ===");
    close(fd);
 }
 return 0;
}
