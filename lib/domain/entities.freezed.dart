// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entities.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StateItem implements DiagnosticableTreeMixin {

/// 状态键
 String get key;/// 状态值（类型安全，由解析时推断并构造对应子类型）
 StateValue get value;
/// Create a copy of StateItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StateItemCopyWith<StateItem> get copyWith => _$StateItemCopyWithImpl<StateItem>(this as StateItem, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'StateItem'))
    ..add(DiagnosticsProperty('key', key))..add(DiagnosticsProperty('value', value));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StateItem&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,key,value);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'StateItem(key: $key, value: $value)';
}


}

/// @nodoc
abstract mixin class $StateItemCopyWith<$Res>  {
  factory $StateItemCopyWith(StateItem value, $Res Function(StateItem) _then) = _$StateItemCopyWithImpl;
@useResult
$Res call({
 String key, StateValue value
});




}
/// @nodoc
class _$StateItemCopyWithImpl<$Res>
    implements $StateItemCopyWith<$Res> {
  _$StateItemCopyWithImpl(this._self, this._then);

  final StateItem _self;
  final $Res Function(StateItem) _then;

/// Create a copy of StateItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? value = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as StateValue,
  ));
}

}


/// Adds pattern-matching-related methods to [StateItem].
extension StateItemPatterns on StateItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StateItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StateItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StateItem value)  $default,){
final _that = this;
switch (_that) {
case _StateItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StateItem value)?  $default,){
final _that = this;
switch (_that) {
case _StateItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  StateValue value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StateItem() when $default != null:
return $default(_that.key,_that.value);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  StateValue value)  $default,) {final _that = this;
switch (_that) {
case _StateItem():
return $default(_that.key,_that.value);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  StateValue value)?  $default,) {final _that = this;
switch (_that) {
case _StateItem() when $default != null:
return $default(_that.key,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _StateItem with DiagnosticableTreeMixin implements StateItem {
  const _StateItem({required this.key, required this.value});
  

/// 状态键
@override final  String key;
/// 状态值（类型安全，由解析时推断并构造对应子类型）
@override final  StateValue value;

/// Create a copy of StateItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StateItemCopyWith<_StateItem> get copyWith => __$StateItemCopyWithImpl<_StateItem>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'StateItem'))
    ..add(DiagnosticsProperty('key', key))..add(DiagnosticsProperty('value', value));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StateItem&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,key,value);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'StateItem(key: $key, value: $value)';
}


}

/// @nodoc
abstract mixin class _$StateItemCopyWith<$Res> implements $StateItemCopyWith<$Res> {
  factory _$StateItemCopyWith(_StateItem value, $Res Function(_StateItem) _then) = __$StateItemCopyWithImpl;
@override @useResult
$Res call({
 String key, StateValue value
});




}
/// @nodoc
class __$StateItemCopyWithImpl<$Res>
    implements _$StateItemCopyWith<$Res> {
  __$StateItemCopyWithImpl(this._self, this._then);

  final _StateItem _self;
  final $Res Function(_StateItem) _then;

/// Create a copy of StateItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? value = null,}) {
  return _then(_StateItem(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as StateValue,
  ));
}


}

/// @nodoc
mixin _$Rule implements DiagnosticableTreeMixin {

/// 规则名称
 String get name;/// 条件表达式（原始字符串）
 String get condition;/// 动作表达式（原始字符串，不含 [group:xxx]）
 String get action;/// 互斥组名（空字符串表示无组）
 String get group;/// 源文件行号（用于错误定位）
 int get line;
/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleCopyWith<Rule> get copyWith => _$RuleCopyWithImpl<Rule>(this as Rule, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Rule'))
    ..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('condition', condition))..add(DiagnosticsProperty('action', action))..add(DiagnosticsProperty('group', group))..add(DiagnosticsProperty('line', line));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Rule&&(identical(other.name, name) || other.name == name)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.action, action) || other.action == action)&&(identical(other.group, group) || other.group == group)&&(identical(other.line, line) || other.line == line));
}


@override
int get hashCode => Object.hash(runtimeType,name,condition,action,group,line);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Rule(name: $name, condition: $condition, action: $action, group: $group, line: $line)';
}


}

/// @nodoc
abstract mixin class $RuleCopyWith<$Res>  {
  factory $RuleCopyWith(Rule value, $Res Function(Rule) _then) = _$RuleCopyWithImpl;
@useResult
$Res call({
 String name, String condition, String action, String group, int line
});




}
/// @nodoc
class _$RuleCopyWithImpl<$Res>
    implements $RuleCopyWith<$Res> {
  _$RuleCopyWithImpl(this._self, this._then);

  final Rule _self;
  final $Res Function(Rule) _then;

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? condition = null,Object? action = null,Object? group = null,Object? line = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Rule].
extension RulePatterns on Rule {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Rule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Rule() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Rule value)  $default,){
final _that = this;
switch (_that) {
case _Rule():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Rule value)?  $default,){
final _that = this;
switch (_that) {
case _Rule() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String condition,  String action,  String group,  int line)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Rule() when $default != null:
return $default(_that.name,_that.condition,_that.action,_that.group,_that.line);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String condition,  String action,  String group,  int line)  $default,) {final _that = this;
switch (_that) {
case _Rule():
return $default(_that.name,_that.condition,_that.action,_that.group,_that.line);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String condition,  String action,  String group,  int line)?  $default,) {final _that = this;
switch (_that) {
case _Rule() when $default != null:
return $default(_that.name,_that.condition,_that.action,_that.group,_that.line);case _:
  return null;

}
}

}

/// @nodoc


class _Rule with DiagnosticableTreeMixin implements Rule {
  const _Rule({required this.name, required this.condition, required this.action, this.group = '', required this.line});
  

/// 规则名称
@override final  String name;
/// 条件表达式（原始字符串）
@override final  String condition;
/// 动作表达式（原始字符串，不含 [group:xxx]）
@override final  String action;
/// 互斥组名（空字符串表示无组）
@override@JsonKey() final  String group;
/// 源文件行号（用于错误定位）
@override final  int line;

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleCopyWith<_Rule> get copyWith => __$RuleCopyWithImpl<_Rule>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Rule'))
    ..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('condition', condition))..add(DiagnosticsProperty('action', action))..add(DiagnosticsProperty('group', group))..add(DiagnosticsProperty('line', line));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Rule&&(identical(other.name, name) || other.name == name)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.action, action) || other.action == action)&&(identical(other.group, group) || other.group == group)&&(identical(other.line, line) || other.line == line));
}


@override
int get hashCode => Object.hash(runtimeType,name,condition,action,group,line);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Rule(name: $name, condition: $condition, action: $action, group: $group, line: $line)';
}


}

/// @nodoc
abstract mixin class _$RuleCopyWith<$Res> implements $RuleCopyWith<$Res> {
  factory _$RuleCopyWith(_Rule value, $Res Function(_Rule) _then) = __$RuleCopyWithImpl;
@override @useResult
$Res call({
 String name, String condition, String action, String group, int line
});




}
/// @nodoc
class __$RuleCopyWithImpl<$Res>
    implements _$RuleCopyWith<$Res> {
  __$RuleCopyWithImpl(this._self, this._then);

  final _Rule _self;
  final $Res Function(_Rule) _then;

/// Create a copy of Rule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? condition = null,Object? action = null,Object? group = null,Object? line = null,}) {
  return _then(_Rule(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,line: null == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$HistoryEntry implements DiagnosticableTreeMixin {

/// 消息角色
 MessageRole get role;/// 消息内容
 String get content;
/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HistoryEntryCopyWith<HistoryEntry> get copyWith => _$HistoryEntryCopyWithImpl<HistoryEntry>(this as HistoryEntry, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'HistoryEntry'))
    ..add(DiagnosticsProperty('role', role))..add(DiagnosticsProperty('content', content));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HistoryEntry&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content));
}


@override
int get hashCode => Object.hash(runtimeType,role,content);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'HistoryEntry(role: $role, content: $content)';
}


}

/// @nodoc
abstract mixin class $HistoryEntryCopyWith<$Res>  {
  factory $HistoryEntryCopyWith(HistoryEntry value, $Res Function(HistoryEntry) _then) = _$HistoryEntryCopyWithImpl;
@useResult
$Res call({
 MessageRole role, String content
});




}
/// @nodoc
class _$HistoryEntryCopyWithImpl<$Res>
    implements $HistoryEntryCopyWith<$Res> {
  _$HistoryEntryCopyWithImpl(this._self, this._then);

  final HistoryEntry _self;
  final $Res Function(HistoryEntry) _then;

/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? content = null,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [HistoryEntry].
extension HistoryEntryPatterns on HistoryEntry {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HistoryEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HistoryEntry value)  $default,){
final _that = this;
switch (_that) {
case _HistoryEntry():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HistoryEntry value)?  $default,){
final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MessageRole role,  String content)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
return $default(_that.role,_that.content);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MessageRole role,  String content)  $default,) {final _that = this;
switch (_that) {
case _HistoryEntry():
return $default(_that.role,_that.content);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MessageRole role,  String content)?  $default,) {final _that = this;
switch (_that) {
case _HistoryEntry() when $default != null:
return $default(_that.role,_that.content);case _:
  return null;

}
}

}

/// @nodoc


class _HistoryEntry with DiagnosticableTreeMixin implements HistoryEntry {
  const _HistoryEntry({required this.role, required this.content});
  

/// 消息角色
@override final  MessageRole role;
/// 消息内容
@override final  String content;

/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HistoryEntryCopyWith<_HistoryEntry> get copyWith => __$HistoryEntryCopyWithImpl<_HistoryEntry>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'HistoryEntry'))
    ..add(DiagnosticsProperty('role', role))..add(DiagnosticsProperty('content', content));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HistoryEntry&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content));
}


@override
int get hashCode => Object.hash(runtimeType,role,content);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'HistoryEntry(role: $role, content: $content)';
}


}

/// @nodoc
abstract mixin class _$HistoryEntryCopyWith<$Res> implements $HistoryEntryCopyWith<$Res> {
  factory _$HistoryEntryCopyWith(_HistoryEntry value, $Res Function(_HistoryEntry) _then) = __$HistoryEntryCopyWithImpl;
@override @useResult
$Res call({
 MessageRole role, String content
});




}
/// @nodoc
class __$HistoryEntryCopyWithImpl<$Res>
    implements _$HistoryEntryCopyWith<$Res> {
  __$HistoryEntryCopyWithImpl(this._self, this._then);

  final _HistoryEntry _self;
  final $Res Function(_HistoryEntry) _then;

/// Create a copy of HistoryEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? content = null,}) {
  return _then(_HistoryEntry(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as MessageRole,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
