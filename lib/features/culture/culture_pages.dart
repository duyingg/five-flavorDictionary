import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/app_routes.dart';
import '../../core/widgets/common_widgets.dart';
import '../data/han_script_converter.dart';
import '../data/poetry_binary_codec.dart';
import '../domain/models.dart';
import '../learning/favorite_item.dart';
import '../learning/favorite_feedback.dart';
import 'festival_section.dart';
import 'ancient_titles_section.dart';
import 'school_books.dart';

part 'reading_annotations_part.dart';
part 'article_reader_part.dart';
part 'culture_home_part.dart';
part 'poetry_browser_part.dart';
part 'culture_detail_part.dart';
part 'poetry_detail_part.dart';
