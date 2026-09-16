#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <unistd.h>

static void Log(NSString *s) {
    NSString *p=@"/var/mobile/A510Player.log";
    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:p];
    if(!h){ [s writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    [h seekToEndOfFile];
    [h writeData:[[s stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [h closeFile];
}
static NSString *Req(NSString *method, NSString *url, int cseq, NSString *extra) {
    return [NSString stringWithFormat:@"%@ %@ RTSP/1.0\r\nCSeq: %d\r\nUser-Agent: A510Player/0.1\r\n%@\r\n",
            method,url,cseq,extra?:@""];
}
int main(int argc,char **argv){
 @autoreleasepool {
    Log(@"\n=== A510 PROBE START ===");
    int s=socket(AF_INET,SOCK_STREAM,0);
    struct sockaddr_in a={0}; a.sin_family=AF_INET; a.sin_port=htons(554);
    inet_pton(AF_INET,"192.168.0.1",&a.sin_addr);
    if(connect(s,(struct sockaddr*)&a,sizeof(a))<0){ Log(@"CONNECT FAILED"); return 2; }
    Log(@"CONNECTED 192.168.0.1:554");
    NSString *url=@"rtsp://192.168.0.1:554/livestream/12";
    NSArray *methods=@[@"OPTIONS",@"DESCRIBE"];
    int c=1;
    for(NSString *m in methods){
        NSString *extra=[m isEqual:@"DESCRIBE"]?@"Accept: application/sdp\r\n":@"";
        NSData *d=[[Req(m,url,c++,extra) dataUsingEncoding:NSUTF8StringEncoding] copy];
        send(s,d.bytes,d.length,0);
        char b[16384]; ssize_t n=recv(s,b,sizeof(b)-1,0);
        if(n>0){ b[n]=0; Log([NSString stringWithUTF8String:b]); }
        else Log(@"NO RESPONSE");
    }
    close(s);
    Log(@"=== A510 PROBE END ===");
 }
 return 0;
}
