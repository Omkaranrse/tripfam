import 'package:flutter/material.dart';

enum DeviceBreakpoint { compact, medium, expanded }

abstract final class Breakpoints {
  static const double compactMax = 599.9;
  static const double mediumMin = 600.0;
  static const double mediumMax = 1023.9;
  static const double expandedMin = 1024.0;
  static const double maxContentWidth = 1200.0;
  static const double shortHeightThreshold = 480.0;

  static DeviceBreakpoint fromWidth(double width) {
    if (width < mediumMin) {
      return DeviceBreakpoint.compact;
    }
    if (width < expandedMin) {
      return DeviceBreakpoint.medium;
    }
    return DeviceBreakpoint.expanded;
  }

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mediumMin;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mediumMin && width < expandedMin;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expandedMin;

  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortHeightThreshold;
}

extension ResponsiveContext on BuildContext {
  DeviceBreakpoint get deviceBreakpoint =>
      Breakpoints.fromWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => Breakpoints.isCompact(this);
  bool get isMedium => Breakpoints.isMedium(this);
  bool get isExpanded => Breakpoints.isExpanded(this);
  bool get isShort => Breakpoints.isShort(this);

  /// Unified page-padding token: 20 compact, 32 medium, 48 expanded
  double get pagePaddingHorizontal {
    if (isCompact) return 20.0;
    if (isMedium) return 32.0;
    return 48.0;
  }

  EdgeInsets get pagePaddingInsets => EdgeInsets.symmetric(
        horizontal: pagePaddingHorizontal,
        vertical: 16.0,
      );
}
