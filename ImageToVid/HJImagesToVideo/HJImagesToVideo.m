//
//  HJImagesToVideo.m
//  HJImagesToVideo
//
//  Created by Harrison Jackson on 8/4/13.
//  Copyright (c) 2013 Harrison Jackson. All rights reserved.
//

#import "HJImagesToVideo.h"

CGSize DefaultFrameSize = (CGSize){480, 320};
NSInteger DefaultFrameRate = 3;

@implementation HJImagesToVideo

+ (void)videoFromImages:(NSArray *)images
                 toPath:(NSString *)path
      withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo videoFromImages:images
                              toPath:path
                            withSize:DefaultFrameSize
                             withFPS:DefaultFrameRate
                   withCallbackBlock:callbackBlock];
}

+ (void)videoFromImages:(NSArray *)images
                 toPath:(NSString *)path
                withFPS:(int)fps
      withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo videoFromImages:images
                              toPath:path
                            withSize:DefaultFrameSize
                             withFPS:fps
                   withCallbackBlock:callbackBlock];
}

+ (void)videoFromImages:(NSArray *)images
                 toPath:(NSString *)path
               withSize:(CGSize)size
      withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo videoFromImages:images
                              toPath:path
                            withSize:size
                             withFPS:DefaultFrameRate
                   withCallbackBlock:callbackBlock];
}

+ (void)videoFromImages:(NSArray *)images
                 toPath:(NSString *)path
               withSize:(CGSize)size
                withFPS:(int)fps
      withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo writeImageAsMovie:images
                                toPath:path
                                  size:size
                                   fps:fps
                     withCallbackBlock:callbackBlock];
}


+ (void)saveVideoToPhotosWithImages:(NSArray *)images
                  withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo saveVideoToPhotosWithImages:images
                                        withSize:DefaultFrameSize
                               withCallbackBlock:callbackBlock];
}

+ (void)saveVideoToPhotosWithImages:(NSArray *)images
                           withSize:(CGSize)size
                  withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo saveVideoToPhotosWithImages:images
                                        withSize:size
                                         withFPS:DefaultFrameRate
                               withCallbackBlock:callbackBlock];
}

+ (void)saveVideoToPhotosWithImages:(NSArray *)images
                            withFPS:(int)fps
                  withCallbackBlock:(SuccessBlock)callbackBlock
{
    [HJImagesToVideo saveVideoToPhotosWithImages:images
                                        withSize:DefaultFrameSize
                                         withFPS:fps
                               withCallbackBlock:callbackBlock];
}

+ (void)saveVideoToPhotosWithImages:(NSArray *)images
                           withSize:(CGSize)size
                            withFPS:(int)fps
                  withCallbackBlock:(SuccessBlock)callbackBlock
{
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"temp.mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
    
    [HJImagesToVideo videoFromImages:images
                              toPath:tempPath
                            withSize:size
                             withFPS:fps
                   withCallbackBlock:^(BOOL success) {
                       
                       if (success) {
                           UISaveVideoAtPathToSavedPhotosAlbum(tempPath, self, nil, nil);
                       }
                       
                       if (callbackBlock) {
                           callbackBlock(success);
                       }
                   }];
}

+ (void)writeImageAsMovie:(NSArray *)array
                   toPath:(NSString*)path
                     size:(CGSize)size
                      fps:(int)fps
        withCallbackBlock:(SuccessBlock)callbackBlock
{
    NSLog(@"%@", path);
    NSError *error = nil;
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                           fileType:AVFileTypeMPEG4
                                                              error:&error];
    if (error) {
        if (callbackBlock) {
            callbackBlock(NO);
        }
        return;
    }
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                   AVVideoWidthKey: [NSNumber numberWithInt:size.width],
                                   AVVideoHeightKey: [NSNumber numberWithInt:size.height]};
    AVAssetWriterInput* writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                         outputSettings:videoSettings];
    
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                     sourcePixelBufferAttributes:nil];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
    
    //Start a session:
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    buffer = [HJImagesToVideo pixelBufferFromCGImage:[array[0] CGImage] size:CGSizeMake(480, 320)];
    CVPixelBufferPoolCreatePixelBuffer (NULL, adaptor.pixelBufferPool, &buffer);
    
    int i = 0;
    while (1)
    {
        
		if(writerInput.readyForMoreMediaData){
            
			CMTime frameTime = CMTimeMake(1, fps );
			CMTime lastTime = CMTimeMake(i, fps);
			CMTime presentTime = CMTimeAdd(lastTime, frameTime);
			
			if (i >= [array count]) {
				buffer = NULL;
			} else {
				buffer = [HJImagesToVideo pixelBufferFromCGImage:[array[i] CGImage] size:CGSizeMake(480, 320)];
			}
			
			
			if (buffer) {
				// append buffer
				[adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
				i++;
			} else {
				
				//Finish the session:
				[writerInput markAsFinished];
                
				[videoWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"Successfully closed video writer");
                    if (videoWriter.status == AVAssetWriterStatusCompleted) {
                        if (callbackBlock) {
                            callbackBlock(YES);
                        }
                    } else {
                        if (callbackBlock) {
                            callbackBlock(NO);
                        }
                    }
                }];
				
				CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
				
				NSLog (@"Done");
                break;
            }
        }
    }
}

+ (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
                                      size:(CGSize)imageSize
{
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                             (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, imageSize.width,
                                          imageSize.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, imageSize.width,
                                                 imageSize.height, 8, 4*imageSize.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextDrawImage(context, CGRectMake(0 + (imageSize.width-CGImageGetWidth(image))/2,
                                           (imageSize.height-CGImageGetHeight(image))/2,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}




@end