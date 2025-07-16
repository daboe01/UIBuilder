/*
 * AppController.j
 * NewApplication
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@import "UIBuilderConstants.j";
@import "UIElementView.j";
@import "UIWindowView.j";
@import "UIButtonView.j";
@import "UISliderView.j";
@import "UITextFieldView.j";
@import "UICheckBoxView.j";
@import "UILabelView.j";
@import "UISearchFieldView.j";
@import "UISecureFieldView.j";
@import "UITextViewView.j";
@import "UIScrollViewView.j";
@import "UITableViewView.j";
@import "UISplitViewView.j";
@import "UIImageViewView.j";
@import "UIPopUpButtonView.j";
@import "UIComboBoxView.j";
@import "UIStepperView.j";
@import "UIDatePickerView.j";
@import "UIProgressIndicatorView.j";
@import "UIBoxView.j";
@import "UICanvasView.j";
@import "AppController.j";

function main(args, namedArgs)
{
    // Force initialization of all UIElementView subclasses
    var subclasses = [UIWindowView, UIButtonView, UISliderView, UITextFieldView, UICheckBoxView, UILabelView, UISearchFieldView, UISecureFieldView, UITextViewView, UIScrollViewView, UITableViewView, UISplitViewView, UIImageViewView, UIPopUpButtonView, UIComboBoxView, UIStepperView, UIDatePickerView, UIProgressIndicatorView, UIBoxView];
    for (var i = 0; i < subclasses.length; i++) {
        [subclasses[i] initialize];
    }

    CPApplicationMain();
}