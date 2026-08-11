// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contract.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Contract {

/// 角色名（必选）
 String get roleName;/// 锚点（核心人格设定，推荐）
 List<StateItem> get anchor; String get worldview; String get background; String get opening;/// 初始状态
 List<StateItem> get state;/// 规则列表
 List<Rule> get rules;/// 分支的一句话描述（来自系统保留区块 `@命运`）
///
/// 仅子版可能有；用户在「另存为分支」时填写。
/// 非空时 serializer 输出 `@命运` 区块，首页据此展示「命运一句话」。
 String get branchTitle;/// 记忆
 List<Memory> get memories;/// 历史
 List<HistoryEntry> get history;
/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContractCopyWith<Contract> get copyWith => _$ContractCopyWithImpl<Contract>(this as Contract, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Contract&&(identical(other.roleName, roleName) || other.roleName == roleName)&&const DeepCollectionEquality().equals(other.anchor, anchor)&&(identical(other.worldview, worldview) || other.worldview == worldview)&&(identical(other.background, background) || other.background == background)&&(identical(other.opening, opening) || other.opening == opening)&&const DeepCollectionEquality().equals(other.state, state)&&const DeepCollectionEquality().equals(other.rules, rules)&&(identical(other.branchTitle, branchTitle) || other.branchTitle == branchTitle)&&const DeepCollectionEquality().equals(other.memories, memories)&&const DeepCollectionEquality().equals(other.history, history));
}


@override
int get hashCode => Object.hash(runtimeType,roleName,const DeepCollectionEquality().hash(anchor),worldview,background,opening,const DeepCollectionEquality().hash(state),const DeepCollectionEquality().hash(rules),branchTitle,const DeepCollectionEquality().hash(memories),const DeepCollectionEquality().hash(history));

@override
String toString() {
  return 'Contract(roleName: $roleName, anchor: $anchor, worldview: $worldview, background: $background, opening: $opening, state: $state, rules: $rules, branchTitle: $branchTitle, memories: $memories, history: $history)';
}


}

/// @nodoc
abstract mixin class $ContractCopyWith<$Res>  {
  factory $ContractCopyWith(Contract value, $Res Function(Contract) _then) = _$ContractCopyWithImpl;
@useResult
$Res call({
 String roleName, List<StateItem> anchor, String worldview, String background, String opening, List<StateItem> state, List<Rule> rules, String branchTitle, List<Memory> memories, List<HistoryEntry> history
});




}
/// @nodoc
class _$ContractCopyWithImpl<$Res>
    implements $ContractCopyWith<$Res> {
  _$ContractCopyWithImpl(this._self, this._then);

  final Contract _self;
  final $Res Function(Contract) _then;

/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? roleName = null,Object? anchor = null,Object? worldview = null,Object? background = null,Object? opening = null,Object? state = null,Object? rules = null,Object? branchTitle = null,Object? memories = null,Object? history = null,}) {
  return _then(_self.copyWith(
roleName: null == roleName ? _self.roleName : roleName // ignore: cast_nullable_to_non_nullable
as String,anchor: null == anchor ? _self.anchor : anchor // ignore: cast_nullable_to_non_nullable
as List<StateItem>,worldview: null == worldview ? _self.worldview : worldview // ignore: cast_nullable_to_non_nullable
as String,background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as String,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as List<StateItem>,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<Rule>,branchTitle: null == branchTitle ? _self.branchTitle : branchTitle // ignore: cast_nullable_to_non_nullable
as String,memories: null == memories ? _self.memories : memories // ignore: cast_nullable_to_non_nullable
as List<Memory>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<HistoryEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [Contract].
extension ContractPatterns on Contract {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Contract value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Contract() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Contract value)  $default,){
final _that = this;
switch (_that) {
case _Contract():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Contract value)?  $default,){
final _that = this;
switch (_that) {
case _Contract() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String roleName,  List<StateItem> anchor,  String worldview,  String background,  String opening,  List<StateItem> state,  List<Rule> rules,  String branchTitle,  List<Memory> memories,  List<HistoryEntry> history)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Contract() when $default != null:
return $default(_that.roleName,_that.anchor,_that.worldview,_that.background,_that.opening,_that.state,_that.rules,_that.branchTitle,_that.memories,_that.history);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String roleName,  List<StateItem> anchor,  String worldview,  String background,  String opening,  List<StateItem> state,  List<Rule> rules,  String branchTitle,  List<Memory> memories,  List<HistoryEntry> history)  $default,) {final _that = this;
switch (_that) {
case _Contract():
return $default(_that.roleName,_that.anchor,_that.worldview,_that.background,_that.opening,_that.state,_that.rules,_that.branchTitle,_that.memories,_that.history);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String roleName,  List<StateItem> anchor,  String worldview,  String background,  String opening,  List<StateItem> state,  List<Rule> rules,  String branchTitle,  List<Memory> memories,  List<HistoryEntry> history)?  $default,) {final _that = this;
switch (_that) {
case _Contract() when $default != null:
return $default(_that.roleName,_that.anchor,_that.worldview,_that.background,_that.opening,_that.state,_that.rules,_that.branchTitle,_that.memories,_that.history);case _:
  return null;

}
}

}

/// @nodoc


class _Contract extends Contract {
  const _Contract({required this.roleName, final  List<StateItem> anchor = const <StateItem>[], this.worldview = '', this.background = '', this.opening = '', final  List<StateItem> state = const <StateItem>[], final  List<Rule> rules = const <Rule>[], this.branchTitle = '', final  List<Memory> memories = const <Memory>[], final  List<HistoryEntry> history = const <HistoryEntry>[]}): _anchor = anchor,_state = state,_rules = rules,_memories = memories,_history = history,super._();
  

/// 角色名（必选）
@override final  String roleName;
/// 锚点（核心人格设定，推荐）
 final  List<StateItem> _anchor;
/// 锚点（核心人格设定，推荐）
@override@JsonKey() List<StateItem> get anchor {
  if (_anchor is EqualUnmodifiableListView) return _anchor;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_anchor);
}

@override@JsonKey() final  String worldview;
@override@JsonKey() final  String background;
@override@JsonKey() final  String opening;
/// 初始状态
 final  List<StateItem> _state;
/// 初始状态
@override@JsonKey() List<StateItem> get state {
  if (_state is EqualUnmodifiableListView) return _state;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_state);
}

/// 规则列表
 final  List<Rule> _rules;
/// 规则列表
@override@JsonKey() List<Rule> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}

/// 分支的一句话描述（来自系统保留区块 `@命运`）
///
/// 仅子版可能有；用户在「另存为分支」时填写。
/// 非空时 serializer 输出 `@命运` 区块，首页据此展示「命运一句话」。
@override@JsonKey() final  String branchTitle;
/// 记忆
 final  List<Memory> _memories;
/// 记忆
@override@JsonKey() List<Memory> get memories {
  if (_memories is EqualUnmodifiableListView) return _memories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_memories);
}

/// 历史
 final  List<HistoryEntry> _history;
/// 历史
@override@JsonKey() List<HistoryEntry> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}


/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContractCopyWith<_Contract> get copyWith => __$ContractCopyWithImpl<_Contract>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Contract&&(identical(other.roleName, roleName) || other.roleName == roleName)&&const DeepCollectionEquality().equals(other._anchor, _anchor)&&(identical(other.worldview, worldview) || other.worldview == worldview)&&(identical(other.background, background) || other.background == background)&&(identical(other.opening, opening) || other.opening == opening)&&const DeepCollectionEquality().equals(other._state, _state)&&const DeepCollectionEquality().equals(other._rules, _rules)&&(identical(other.branchTitle, branchTitle) || other.branchTitle == branchTitle)&&const DeepCollectionEquality().equals(other._memories, _memories)&&const DeepCollectionEquality().equals(other._history, _history));
}


@override
int get hashCode => Object.hash(runtimeType,roleName,const DeepCollectionEquality().hash(_anchor),worldview,background,opening,const DeepCollectionEquality().hash(_state),const DeepCollectionEquality().hash(_rules),branchTitle,const DeepCollectionEquality().hash(_memories),const DeepCollectionEquality().hash(_history));

@override
String toString() {
  return 'Contract(roleName: $roleName, anchor: $anchor, worldview: $worldview, background: $background, opening: $opening, state: $state, rules: $rules, branchTitle: $branchTitle, memories: $memories, history: $history)';
}


}

/// @nodoc
abstract mixin class _$ContractCopyWith<$Res> implements $ContractCopyWith<$Res> {
  factory _$ContractCopyWith(_Contract value, $Res Function(_Contract) _then) = __$ContractCopyWithImpl;
@override @useResult
$Res call({
 String roleName, List<StateItem> anchor, String worldview, String background, String opening, List<StateItem> state, List<Rule> rules, String branchTitle, List<Memory> memories, List<HistoryEntry> history
});




}
/// @nodoc
class __$ContractCopyWithImpl<$Res>
    implements _$ContractCopyWith<$Res> {
  __$ContractCopyWithImpl(this._self, this._then);

  final _Contract _self;
  final $Res Function(_Contract) _then;

/// Create a copy of Contract
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? roleName = null,Object? anchor = null,Object? worldview = null,Object? background = null,Object? opening = null,Object? state = null,Object? rules = null,Object? branchTitle = null,Object? memories = null,Object? history = null,}) {
  return _then(_Contract(
roleName: null == roleName ? _self.roleName : roleName // ignore: cast_nullable_to_non_nullable
as String,anchor: null == anchor ? _self._anchor : anchor // ignore: cast_nullable_to_non_nullable
as List<StateItem>,worldview: null == worldview ? _self.worldview : worldview // ignore: cast_nullable_to_non_nullable
as String,background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as String,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self._state : state // ignore: cast_nullable_to_non_nullable
as List<StateItem>,rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<Rule>,branchTitle: null == branchTitle ? _self.branchTitle : branchTitle // ignore: cast_nullable_to_non_nullable
as String,memories: null == memories ? _self._memories : memories // ignore: cast_nullable_to_non_nullable
as List<Memory>,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<HistoryEntry>,
  ));
}


}

// dart format on
