//
//  GameViewController.m
//  Shader Studio
//
//  Created by Stuart Carnie on 4/7/20.
//  Copyright © 2020 OpenEmu. All rights reserved.
//

#import "GameViewController.h"
#import "Renderer.h"

@implementation GameViewController
{
    MTKView *_view;

    Renderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (MTKView *)self.view;

    _view.device = MTLCreateSystemDefaultDevice();

    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }
}

- (void)viewWillAppear
{
    _renderer = [[Renderer alloc] initWithMetalKitView:_view];
    CGFloat scale = _view.window.backingScaleFactor;
    CGSize size = CGSizeApplyAffineTransform(_view.bounds.size, CGAffineTransformMakeScale(scale, scale));
    [_renderer mtkView:_view drawableSizeWillChange:size];

    _view.delegate = _renderer;
}

@end
