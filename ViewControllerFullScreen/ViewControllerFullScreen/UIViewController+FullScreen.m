//
//  UIViewController+FullScreen.m
//  ViewControllerFullScreen
//
//  Created by YLCHUN on 16/10/28.
//  Copyright © 2016年 ylchun. All rights reserved.
//

#import "UIViewController+FullScreen.h"
#import <objc/runtime.h>

#pragma mark - swizzleClassMethod
static inline BOOL fs_swizzleClassMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (success) {
        class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    return success;
}

#pragma mark - UIViewController
@implementation UIViewController (FullScreen)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(fs_viewWillAppear:);
        fs_swizzleClassMethod(class, originalSelector, swizzledSelector);
    });
}

-(void)fs_viewWillAppear:(BOOL)animated {
    [self fs_viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:self.navigationBarHidden animated:animated];
}

-(BOOL)navigationBarHidden {
    return [objc_getAssociatedObject(self, @selector(navigationBarHidden)) boolValue];
}

-(void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    objc_setAssociatedObject(self, @selector(navigationBarHidden), @(navigationBarHidden), OBJC_ASSOCIATION_RETAIN);
}

@end

#pragma mark - FS_ScreenEdgePanGestureRecognizer
@interface FS_ScreenEdgePanGestureRecognizer : UIScreenEdgePanGestureRecognizer
@end
@implementation FS_ScreenEdgePanGestureRecognizer
@end

#pragma mark - UINavigationController
@interface UINavigationController ()
@property (nonatomic) FS_ScreenEdgePanGestureRecognizer *fs_popGestureRecognizer;
@end

@implementation UINavigationController (FullScreen)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector;
        SEL swizzledSelector;
        
        originalSelector = @selector(init);
        swizzledSelector = @selector(fs_init);
        fs_swizzleClassMethod(class, originalSelector, swizzledSelector);
        
        originalSelector = @selector(initWithCoder:);
        swizzledSelector = @selector(fs_initWithCoder:);
        fs_swizzleClassMethod(class, originalSelector, swizzledSelector);
        
        originalSelector = @selector(initWithNibName:bundle:);
        swizzledSelector = @selector(fs_initWithNibName:bundle:);
        fs_swizzleClassMethod(class, originalSelector, swizzledSelector);
        
        originalSelector = @selector(initWithNavigationBarClass:toolbarClass:);
        swizzledSelector = @selector(fs_initWithNavigationBarClass:toolbarClass:);
        fs_swizzleClassMethod(class, originalSelector, swizzledSelector);
    });
}

-(instancetype)fs_init {
    UINavigationController *nvc = [self fs_init];
    [nvc performSelector:@selector(initNewPopGestureRecognizer) withObject:nil afterDelay:0.2];
    return nvc;
}

-(instancetype)fs_initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    UINavigationController *nvc = [self fs_initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    [nvc performSelector:@selector(initNewPopGestureRecognizer) withObject:nil afterDelay:0.2];
    return nvc;
}

-(instancetype)fs_initWithCoder:(NSCoder *)aDecoder {
    UINavigationController *nvc = [self fs_initWithCoder:aDecoder];
    [nvc performSelector:@selector(initNewPopGestureRecognizer) withObject:nil afterDelay:0.2];
    return nvc;
}

- (instancetype)fs_initWithRootViewController:(UIViewController *)rootViewController {
    UINavigationController* nvc = [self fs_initWithRootViewController:rootViewController];
    [nvc performSelector:@selector(initNewPopGestureRecognizer) withObject:nil afterDelay:0.2];
    return nvc;
}

-(instancetype)fs_initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass {
    UINavigationController* nvc = [self fs_initWithNavigationBarClass:navigationBarClass toolbarClass:toolbarClass];
    [nvc performSelector:@selector(initNewPopGestureRecognizer) withObject:nil afterDelay:0.2];
    return nvc;
}

-(void)initNewPopGestureRecognizer {
    if (!self.fs_popGestureRecognizer) {
        self.fs_popGestureRecognizer = [[FS_ScreenEdgePanGestureRecognizer alloc] init];
        self.fs_popGestureRecognizer.edges = UIRectEdgeLeft;
        NSArray *internalTargets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id internalTarget = [internalTargets.firstObject valueForKey:@"target"];
        SEL internalAction = NSSelectorFromString(@"handleNavigationTransition:");
        [self.fs_popGestureRecognizer addTarget:internalTarget action:internalAction];
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.fs_popGestureRecognizer];
        self.fs_popGestureRecognizer.delegate = (id <UIGestureRecognizerDelegate>)self;
        self.interactivePopGestureRecognizer.enabled = false;
    }
}

-(FS_ScreenEdgePanGestureRecognizer *)fs_popGestureRecognizer {
    return objc_getAssociatedObject(self, @selector(fs_popGestureRecognizer));
}

-(void)setFs_popGestureRecognizer:(FS_ScreenEdgePanGestureRecognizer *)fs_popGestureRecognizer {
    objc_setAssociatedObject(self, @selector(fs_popGestureRecognizer), fs_popGestureRecognizer, OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return self.viewControllers.count != 1;
}

@end

#pragma mark - FS_DelegateInterceptor
@interface FS_DelegateInterceptor : NSObject
@property (nonatomic, readwrite, weak) UIScrollView<UIGestureRecognizerDelegate> *scrollView;
@end

@implementation FS_DelegateInterceptor

-(instancetype)initWithScrllView:(UIScrollView*)scrollView {
    self = [super init];
    if (self) {
        self.scrollView = (UIScrollView<UIGestureRecognizerDelegate> *)scrollView;
        [scrollView.panGestureRecognizer setValue:self forKey:@"_scrollView"];
        scrollView.panGestureRecognizer.delegate = (id<UIGestureRecognizerDelegate>)self;
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([otherGestureRecognizer isKindOfClass:[FS_ScreenEdgePanGestureRecognizer class]]) {
        return true;
    }
    if ([self.scrollView respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)]) {
        return [self.scrollView gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
    }
    return false;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([otherGestureRecognizer isKindOfClass:[FS_ScreenEdgePanGestureRecognizer class]]) {
        UIEdgeInsets contentInset = self.scrollView.contentInset;
        CGPoint contentOffset = self.scrollView.contentOffset;
        CGSize contentSize = self.scrollView.contentSize;
        CGSize size = self.scrollView.bounds.size;

        CGFloat x1 = 0-contentInset.left;
        if (contentOffset.x < x1) {
            contentOffset.x = x1;
        }
        CGFloat x2 = contentSize.width-size.width+contentInset.right;
        if (contentOffset.x > x2) {
            contentOffset.x = x2;
        }
        CGFloat y1 = 0-contentInset.top;
        if (contentOffset.y < y1) {
            contentOffset.y = y1;
        }
        CGFloat y2 = contentSize.height-size.height+contentInset.bottom;
        if (contentOffset.y > y2) {
            contentOffset.y = y2;
        }
        [self.scrollView setContentOffset:contentOffset animated:true];
        return true;
    }
    if ([self.scrollView respondsToSelector:@selector(gestureRecognizer:shouldRequireFailureOfGestureRecognizer:)]) {
        return [self.scrollView gestureRecognizer:gestureRecognizer shouldRequireFailureOfGestureRecognizer:otherGestureRecognizer];
    }
    return false;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) {
        return self;
    }
    if (self.scrollView && [self.scrollView respondsToSelector:aSelector]) {
        return self.scrollView;
    }
    return nil;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) {
        return YES;
    }
    if (self.scrollView && [self.scrollView respondsToSelector:aSelector]) {
        return YES;
    }
    return false;
}

@end

#pragma mark - UIScrollView
@interface UIScrollView (FullScreen)
@property (nonatomic) FS_DelegateInterceptor *fs_delegateInterceptor;
@end

@implementation UIScrollView (FullScreen)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(didMoveToSuperview);
        SEL swizzledSelector = @selector(fs_didMoveToSuperview);
        fs_swizzleClassMethod(class, originalSelector, swizzledSelector);
    });
}

-(void)fs_didMoveToSuperview {
    [self fs_didMoveToSuperview];
    [self fs_delegateInterceptor];
}

-(FS_DelegateInterceptor *)fs_delegateInterceptor {
    FS_DelegateInterceptor *fs_delegateInterceptor = objc_getAssociatedObject(self, @selector(fs_delegateInterceptor));
    if (!fs_delegateInterceptor) {
        fs_delegateInterceptor = [[FS_DelegateInterceptor alloc]initWithScrllView:self];
        [self setFs_delegateInterceptor:fs_delegateInterceptor];
    }
    return fs_delegateInterceptor;
}

-(void)setFs_delegateInterceptor:(FS_DelegateInterceptor *)fs_delegateInterceptor {
    objc_setAssociatedObject(self, @selector(fs_delegateInterceptor), fs_delegateInterceptor, OBJC_ASSOCIATION_RETAIN);
}

@end

