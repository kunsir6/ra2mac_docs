// 基准：CGImageCreate 每帧到底花多少？——ON-2-01 的前提"每秒上百 MB 分配"是否成立。
//
// 三个变体：
//   A. provider + image 每帧新建（当前实现）
//   B. provider 缓存 + image 每帧新建
//   C. provider + image 都缓存（仅赋 layer.contents）
// 只测 CPU 时间，不涉及上传（上传在提交时发生，与对象创建无关）。
#import <Cocoa/Cocoa.h>
#include <CoreGraphics/CoreGraphics.h>
#include <chrono>
#include <cstdio>

int main() {
    setvbuf(stdout, nullptr, _IONBF, 0);
    const int W = 1024, H = 640;
    static unsigned char buffer[W * H * 4];
    const CGBitmapInfo info = static_cast<CGBitmapInfo>(
        static_cast<std::uint32_t>(kCGBitmapByteOrder32Little)
        | static_cast<std::uint32_t>(kCGImageAlphaNoneSkipFirst));
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    const int N = 20000;

    auto bench = [&](const char* name, bool cacheProvider, bool cacheImage) {
        CGDataProviderRef provider = nullptr;
        CGImageRef image = nullptr;
        if (cacheProvider) {
            provider = CGDataProviderCreateWithData(nullptr, buffer, sizeof(buffer), nullptr);
        }
        const auto start = std::chrono::steady_clock::now();
        long long creates = 0;
        for (int i = 0; i < N; ++i) {
            buffer[0] = static_cast<unsigned char>(i);
            if (!cacheProvider) {
                provider = CGDataProviderCreateWithData(nullptr, buffer, sizeof(buffer), nullptr);
            }
            CGImageRef candidate = image;
            if (!cacheImage) {
                candidate = CGImageCreate(W, H, 8, 32, W * 4, cs, info, provider,
                                          nullptr, false, kCGRenderingIntentDefault);
                ++creates;
            }
            CGImageRef previous = image;
            image = candidate;
            if (previous != nullptr) CGImageRelease(previous);
            if (!cacheProvider) CGDataProviderRelease(provider);
        }
        if (image != nullptr) CGImageRelease(image);
        const auto end = std::chrono::steady_clock::now();
        const double totalMs =
            std::chrono::duration<double, std::milli>(end - start).count();
        printf("%-34s creates=%-6lld total=%.1fms  perFrame=%.4fms\n",
               name, creates, totalMs, totalMs / N);
    };

    bench("A provider+image per frame", false, false);
    bench("B provider cached, image per frame", true, false);
    bench("C provider+image cached", true, true);
    printf("buffer=%d bytes (%dx%d)\n", W * H * 4, W, H);
    return 0;
}
