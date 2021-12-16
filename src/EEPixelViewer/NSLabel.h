// https://stackoverflow.com/questions/20169298/xcode-doesnt-recognize-nslabel
//
//  NSLabel.h
//
//  Created by Axel Guilmin on 11/5/14.
//

#import <AppKit/AppKit.h>

@interface NSLabel : NSTextField

@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, strong) NSString *text;

@end
