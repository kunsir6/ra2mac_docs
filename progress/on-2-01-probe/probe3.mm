// 隔离实验 v3：CGImage 缓存到 layer.contents 之后，屏幕还会不会更新？
//
// v1/v2 用外部 screencapture，结果被"窗口是否在最前面"污染（WorkBuddy 会抢焦点，
// 被遮挡的窗口抓回来是上一张合成快照）。v3 在进程内自抓，且每次抓之前自己
// activate + orderFront，把"遮挡"这个变量消掉。
//
// MODE=fresh 每帧新建 CGImage（原始实现）
// MODE=alt   两个 CGImage 轮流挂（缓存方案）
// MODE=same  一直挂同一个 CGImage
//
// 每次抓图存 /tmp/pc/probe-<mode>-<phase>.png，颜色按"哪个通道占优"判别。

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CoreAnimation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static unsigned char gBuffer[320 * 240 * 4];
static const int kW = 320;
static const int kH = 240;

static const CGBitmapInfo kInfo = static_cast<CGBitmapInfo>(
    static_cast<std::uint32_t>(kCGBitmapByteOrder32Little)
    | static_cast<std::uint32_t>(kCGImageAlphaNoneSkipFirst));

static void fill(int phase) {
    unsigned char b = 0, g = 0, r = 0;
    switch (phase) {
        case 0: r = 255; break;
        case 1: g = 255; break;
        case 2: b = 255; break;
        default: r = 255; g = 255; break;  // 黄
    }
    for (int i = 0; i < kW * kH; ++i) {
        gBuffer[i * 4 + 0] = b;
        gBuffer[i * 4 + 1] = g;
        gBuffer[i * 4 + 2] = r;
        gBuffer[i * 4 + 3] = 0;
    }
}

static void spin(double seconds) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

int main() {
    setvbuf(stdout, nullptr, _IONBF, 0);
    const char* mode = std::getenv("MODE");
    const bool fresh = (mode != nullptr && std::strcmp(mode, "fresh") == 0);
    const bool alt = (mode != nullptr && std::strcmp(mode, "alt") == 0);
    const char* tag = fresh ? "fresh" : (alt ? "alt" : "same");

    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSRect rect = NSMakeRect(200, 300, kW, kH);
        NSWindow* window = [[NSWindow alloc] initWithContentRect:rect
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
              backing:NSBackingStoreBuffered
                defer:NO];
        NSView* view = [[NSView alloc] initWithFrame:rect];
        view.wantsLayer = YES;
        view.layer.contentsGravity = kCAGravityResize;
        view.layer.contentsScale = window.backingScaleFactor;
        window.contentView = view;
        [window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        printf("mode=%s windowNumber=%d scale=%.1f\n", tag, window.windowNumber,
               window.backingScaleFactor);

        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGImageRef cached[2] = {nullptr, nullptr};
        for (int i = 0; i < 2; ++i) {
            CGDataProviderRef p = CGDataProviderCreateWithData(
                nullptr, gBuffer, sizeof(gBuffer), nullptr);
            cached[i] = CGImageCreate(kW, kH, 8, 32, kW * 4, cs, kInfo, p,
                                      nullptr, false, kCGRenderingIntentDefault);
            CGDataProviderRelease(p);
        }

        int phase = 0;
        fill(phase);
        int slot = 0;
        // 每阶段 24 步 × 50ms = 1.2s；最后 4 步用于抓图（抓完还会再跑几轮刷新）。
        for (int phaseIndex = 0; phaseIndex < 4; ++phaseIndex) {
            phase = phaseIndex;
            fill(phase);
            for (int step = 0; step < 24; ++step) {
                CGImageRef image = nullptr;
                if (fresh) {
                    CGDataProviderRef p = CGDataProviderCreateWithData(
                        nullptr, gBuffer, sizeof(gBuffer), nullptr);
                    image = CGImageCreate(kW, kH, 8, 32, kW * 4, cs, kInfo, p,
                                          nullptr, false, kCGRenderingIntentDefault);
                    CGDataProviderRelease(p);
                } else {
                    image = alt ? cached[slot] : cached[0];
                    slot ^= 1;
                }
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                view.layer.contents = (__bridge id)image;
                [CATransaction commit];
                if (fresh && image != nullptr) CGImageRelease(image);
                spin(0.05);
            }
            // 抓图前把窗口顶到最前：遮挡会让 -l 抓到上一张合成快照。
            [NSApp activateIgnoringOtherApps:YES];
            [window makeKeyAndOrderFront:nil];
            spin(0.25);
            char command[512];
            std::snprintf(command, sizeof(command),
                          "screencapture -x -o -l%d /tmp/pc/probe-%s-%d.png",
                          window.windowNumber, tag, phaseIndex);
            const int rc = std::system(command);
            printf("CAPTURE phase=%d rc=%d\n", phaseIndex, rc);
        }
        printf("DONE mode=%s phases=4\n", tag);
    }
    return 0;
}
