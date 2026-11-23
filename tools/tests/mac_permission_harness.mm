#import <Foundation/Foundation.h>

#include <functional>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

template <typename Signature>
using Fn = std::function<Signature>;

enum class PermissionType { Microphone, Camera };
enum class PermissionStatus { Granted, Denied };

namespace {

const auto AVMediaTypeAudio = @"audio";
const auto AVMediaTypeVideo = @"video";
auto ApiAvailable = true;
auto NativeRequests = 0;
NSString *RequestedMedia = nil;
void (^PendingCompletion)(BOOL) = nil;
auto MainQueue = std::vector<Fn<void()>>();

} // namespace

@interface AVCaptureDevice : NSObject
+ (void)requestAccessForMediaType:(NSString *)media
	completionHandler:(void (^)(BOOL))completion;
@end

@implementation AVCaptureDevice

+ (BOOL)respondsToSelector:(SEL)selector {
	return ApiAvailable;
}

+ (void)requestAccessForMediaType:(NSString *)media
	completionHandler:(void (^)(BOOL))completion {
	++NativeRequests;
	RequestedMedia = media;
	PendingCompletion = [completion copy];
}

@end

namespace crl {

void on_main(Fn<void()> callback) {
	MainQueue.push_back(std::move(callback));
}

} // namespace crl

/* REQUEST_PERMISSION */

namespace {

void DrainMainQueue() {
	const auto callbacks = std::exchange(MainQueue, {});
	for (const auto &callback : callbacks) {
		callback();
	}
}

int RunScenario(PermissionType type, bool granted, bool available) {
	ApiAvailable = available;
	auto results = std::vector<PermissionStatus>();
	auto failures = 0;
	const auto check = [&](bool success, const char *message) {
		if (!success) {
			std::cerr << message << '\n';
			++failures;
		}
	};
	const auto collect = [&](PermissionStatus status) {
		results.push_back(status);
	};
	RequestPermission(type, collect);
	if (!available) {
		check(NativeRequests == 0, "API called when unavailable");
		check(
			results == std::vector{PermissionStatus::Granted},
			"Fallback must deliver exactly one Granted result");
		check(MainQueue.empty(), "Fallback must not enqueue work");
		return failures;
	}
	check(NativeRequests == 1, "Expected one native request");
	const auto expectedMedia = type == PermissionType::Microphone
		? AVMediaTypeAudio
		: AVMediaTypeVideo;
	check(
		[RequestedMedia isEqualToString:expectedMedia],
		"Wrong native media type");
	check(results.empty(), "Callback ran before the user answered");
	check(MainQueue.empty(), "Callback queued before the user answered");
	if (!PendingCompletion) {
		check(false, "Missing native completion handler");
		return failures;
	}
	PendingCompletion(granted);
	PendingCompletion = nil;
	check(results.empty(), "Callback ran outside the main queue");
	check(MainQueue.size() == 1, "Expected one queued callback");
	DrainMainQueue();
	const auto expected = granted
		? PermissionStatus::Granted
		: PermissionStatus::Denied;
	check(results == std::vector{expected}, "Wrong native answer");
	DrainMainQueue();
	check(results.size() == 1, "Permission continuation ran twice");
	return failures;
}

} // namespace

int main(int argc, char *argv[]) {
	@autoreleasepool {
		if (argc != 4) {
			return 2;
		}
		const auto media = std::string(argv[1]);
		const auto type = media == "microphone"
			? PermissionType::Microphone : PermissionType::Camera;
		return RunScenario(
			type,
			std::string(argv[2]) == "grant",
			std::string(argv[3]) == "available") ? 1 : 0;
	}
}
