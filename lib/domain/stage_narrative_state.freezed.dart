// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stage_narrative_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RoleRunState {

 Map<String, StateValue> get currentState; List<Memory> get memories; List<HistoryEntry> get history;
/// Create a copy of RoleRunState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoleRunStateCopyWith<RoleRunState> get copyWith => _$RoleRunStateCopyWithImpl<RoleRunState>(this as RoleRunState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoleRunState&&const DeepCollectionEquality().equals(other.currentState, currentState)&&const DeepCollectionEquality().equals(other.memories, memories)&&const DeepCollectionEquality().equals(other.history, history));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(currentState),const DeepCollectionEquality().hash(memories),const DeepCollectionEquality().hash(history));

@override
String toString() {
  return 'RoleRunState(currentState: $currentState, memories: $memories, history: $history)';
}


}

/// @nodoc
abstract mixin class $RoleRunStateCopyWith<$Res>  {
  factory $RoleRunStateCopyWith(RoleRunState value, $Res Function(RoleRunState) _then) = _$RoleRunStateCopyWithImpl;
@useResult
$Res call({
 Map<String, StateValue> currentState, List<Memory> memories, List<HistoryEntry> history
});




}
/// @nodoc
class _$RoleRunStateCopyWithImpl<$Res>
    implements $RoleRunStateCopyWith<$Res> {
  _$RoleRunStateCopyWithImpl(this._self, this._then);

  final RoleRunState _self;
  final $Res Function(RoleRunState) _then;

/// Create a copy of RoleRunState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentState = null,Object? memories = null,Object? history = null,}) {
  return _then(_self.copyWith(
currentState: null == currentState ? _self.currentState : currentState // ignore: cast_nullable_to_non_nullable
as Map<String, StateValue>,memories: null == memories ? _self.memories : memories // ignore: cast_nullable_to_non_nullable
as List<Memory>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<HistoryEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [RoleRunState].
extension RoleRunStatePatterns on RoleRunState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoleRunState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoleRunState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoleRunState value)  $default,){
final _that = this;
switch (_that) {
case _RoleRunState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoleRunState value)?  $default,){
final _that = this;
switch (_that) {
case _RoleRunState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, StateValue> currentState,  List<Memory> memories,  List<HistoryEntry> history)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoleRunState() when $default != null:
return $default(_that.currentState,_that.memories,_that.history);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, StateValue> currentState,  List<Memory> memories,  List<HistoryEntry> history)  $default,) {final _that = this;
switch (_that) {
case _RoleRunState():
return $default(_that.currentState,_that.memories,_that.history);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, StateValue> currentState,  List<Memory> memories,  List<HistoryEntry> history)?  $default,) {final _that = this;
switch (_that) {
case _RoleRunState() when $default != null:
return $default(_that.currentState,_that.memories,_that.history);case _:
  return null;

}
}

}

/// @nodoc


class _RoleRunState extends RoleRunState {
  const _RoleRunState({final  Map<String, StateValue> currentState = const <String, StateValue>{}, final  List<Memory> memories = const <Memory>[], final  List<HistoryEntry> history = const <HistoryEntry>[]}): _currentState = currentState,_memories = memories,_history = history,super._();
  

 final  Map<String, StateValue> _currentState;
@override@JsonKey() Map<String, StateValue> get currentState {
  if (_currentState is EqualUnmodifiableMapView) return _currentState;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_currentState);
}

 final  List<Memory> _memories;
@override@JsonKey() List<Memory> get memories {
  if (_memories is EqualUnmodifiableListView) return _memories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_memories);
}

 final  List<HistoryEntry> _history;
@override@JsonKey() List<HistoryEntry> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}


/// Create a copy of RoleRunState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoleRunStateCopyWith<_RoleRunState> get copyWith => __$RoleRunStateCopyWithImpl<_RoleRunState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoleRunState&&const DeepCollectionEquality().equals(other._currentState, _currentState)&&const DeepCollectionEquality().equals(other._memories, _memories)&&const DeepCollectionEquality().equals(other._history, _history));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_currentState),const DeepCollectionEquality().hash(_memories),const DeepCollectionEquality().hash(_history));

@override
String toString() {
  return 'RoleRunState(currentState: $currentState, memories: $memories, history: $history)';
}


}

/// @nodoc
abstract mixin class _$RoleRunStateCopyWith<$Res> implements $RoleRunStateCopyWith<$Res> {
  factory _$RoleRunStateCopyWith(_RoleRunState value, $Res Function(_RoleRunState) _then) = __$RoleRunStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, StateValue> currentState, List<Memory> memories, List<HistoryEntry> history
});




}
/// @nodoc
class __$RoleRunStateCopyWithImpl<$Res>
    implements _$RoleRunStateCopyWith<$Res> {
  __$RoleRunStateCopyWithImpl(this._self, this._then);

  final _RoleRunState _self;
  final $Res Function(_RoleRunState) _then;

/// Create a copy of RoleRunState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentState = null,Object? memories = null,Object? history = null,}) {
  return _then(_RoleRunState(
currentState: null == currentState ? _self._currentState : currentState // ignore: cast_nullable_to_non_nullable
as Map<String, StateValue>,memories: null == memories ? _self._memories : memories // ignore: cast_nullable_to_non_nullable
as List<Memory>,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<HistoryEntry>,
  ));
}


}

/// @nodoc
mixin _$StageNarrativeState {

 StageLoaded? get stage; String get stagePath; Map<String, RoleRunState> get roles; List<Message> get messages; bool get isGenerating; String get streamingContent; String get lastError; List<DiceResult> get diceResults; String get lastRollInfo; List<String> get attachedFileNames; List<String> get attachedContexts;
/// Create a copy of StageNarrativeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StageNarrativeStateCopyWith<StageNarrativeState> get copyWith => _$StageNarrativeStateCopyWithImpl<StageNarrativeState>(this as StageNarrativeState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StageNarrativeState&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.stagePath, stagePath) || other.stagePath == stagePath)&&const DeepCollectionEquality().equals(other.roles, roles)&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.isGenerating, isGenerating) || other.isGenerating == isGenerating)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&const DeepCollectionEquality().equals(other.diceResults, diceResults)&&(identical(other.lastRollInfo, lastRollInfo) || other.lastRollInfo == lastRollInfo)&&const DeepCollectionEquality().equals(other.attachedFileNames, attachedFileNames)&&const DeepCollectionEquality().equals(other.attachedContexts, attachedContexts));
}


@override
int get hashCode => Object.hash(runtimeType,stage,stagePath,const DeepCollectionEquality().hash(roles),const DeepCollectionEquality().hash(messages),isGenerating,streamingContent,lastError,const DeepCollectionEquality().hash(diceResults),lastRollInfo,const DeepCollectionEquality().hash(attachedFileNames),const DeepCollectionEquality().hash(attachedContexts));

@override
String toString() {
  return 'StageNarrativeState(stage: $stage, stagePath: $stagePath, roles: $roles, messages: $messages, isGenerating: $isGenerating, streamingContent: $streamingContent, lastError: $lastError, diceResults: $diceResults, lastRollInfo: $lastRollInfo, attachedFileNames: $attachedFileNames, attachedContexts: $attachedContexts)';
}


}

/// @nodoc
abstract mixin class $StageNarrativeStateCopyWith<$Res>  {
  factory $StageNarrativeStateCopyWith(StageNarrativeState value, $Res Function(StageNarrativeState) _then) = _$StageNarrativeStateCopyWithImpl;
@useResult
$Res call({
 StageLoaded? stage, String stagePath, Map<String, RoleRunState> roles, List<Message> messages, bool isGenerating, String streamingContent, String lastError, List<DiceResult> diceResults, String lastRollInfo, List<String> attachedFileNames, List<String> attachedContexts
});




}
/// @nodoc
class _$StageNarrativeStateCopyWithImpl<$Res>
    implements $StageNarrativeStateCopyWith<$Res> {
  _$StageNarrativeStateCopyWithImpl(this._self, this._then);

  final StageNarrativeState _self;
  final $Res Function(StageNarrativeState) _then;

/// Create a copy of StageNarrativeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stage = freezed,Object? stagePath = null,Object? roles = null,Object? messages = null,Object? isGenerating = null,Object? streamingContent = null,Object? lastError = null,Object? diceResults = null,Object? lastRollInfo = null,Object? attachedFileNames = null,Object? attachedContexts = null,}) {
  return _then(_self.copyWith(
stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as StageLoaded?,stagePath: null == stagePath ? _self.stagePath : stagePath // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self.roles : roles // ignore: cast_nullable_to_non_nullable
as Map<String, RoleRunState>,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,isGenerating: null == isGenerating ? _self.isGenerating : isGenerating // ignore: cast_nullable_to_non_nullable
as bool,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,diceResults: null == diceResults ? _self.diceResults : diceResults // ignore: cast_nullable_to_non_nullable
as List<DiceResult>,lastRollInfo: null == lastRollInfo ? _self.lastRollInfo : lastRollInfo // ignore: cast_nullable_to_non_nullable
as String,attachedFileNames: null == attachedFileNames ? _self.attachedFileNames : attachedFileNames // ignore: cast_nullable_to_non_nullable
as List<String>,attachedContexts: null == attachedContexts ? _self.attachedContexts : attachedContexts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [StageNarrativeState].
extension StageNarrativeStatePatterns on StageNarrativeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StageNarrativeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StageNarrativeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StageNarrativeState value)  $default,){
final _that = this;
switch (_that) {
case _StageNarrativeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StageNarrativeState value)?  $default,){
final _that = this;
switch (_that) {
case _StageNarrativeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StageLoaded? stage,  String stagePath,  Map<String, RoleRunState> roles,  List<Message> messages,  bool isGenerating,  String streamingContent,  String lastError,  List<DiceResult> diceResults,  String lastRollInfo,  List<String> attachedFileNames,  List<String> attachedContexts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StageNarrativeState() when $default != null:
return $default(_that.stage,_that.stagePath,_that.roles,_that.messages,_that.isGenerating,_that.streamingContent,_that.lastError,_that.diceResults,_that.lastRollInfo,_that.attachedFileNames,_that.attachedContexts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StageLoaded? stage,  String stagePath,  Map<String, RoleRunState> roles,  List<Message> messages,  bool isGenerating,  String streamingContent,  String lastError,  List<DiceResult> diceResults,  String lastRollInfo,  List<String> attachedFileNames,  List<String> attachedContexts)  $default,) {final _that = this;
switch (_that) {
case _StageNarrativeState():
return $default(_that.stage,_that.stagePath,_that.roles,_that.messages,_that.isGenerating,_that.streamingContent,_that.lastError,_that.diceResults,_that.lastRollInfo,_that.attachedFileNames,_that.attachedContexts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StageLoaded? stage,  String stagePath,  Map<String, RoleRunState> roles,  List<Message> messages,  bool isGenerating,  String streamingContent,  String lastError,  List<DiceResult> diceResults,  String lastRollInfo,  List<String> attachedFileNames,  List<String> attachedContexts)?  $default,) {final _that = this;
switch (_that) {
case _StageNarrativeState() when $default != null:
return $default(_that.stage,_that.stagePath,_that.roles,_that.messages,_that.isGenerating,_that.streamingContent,_that.lastError,_that.diceResults,_that.lastRollInfo,_that.attachedFileNames,_that.attachedContexts);case _:
  return null;

}
}

}

/// @nodoc


class _StageNarrativeState extends StageNarrativeState {
  const _StageNarrativeState({this.stage, this.stagePath = '', final  Map<String, RoleRunState> roles = const <String, RoleRunState>{}, final  List<Message> messages = const <Message>[], this.isGenerating = false, this.streamingContent = '', this.lastError = '', final  List<DiceResult> diceResults = const <DiceResult>[], this.lastRollInfo = '', final  List<String> attachedFileNames = const <String>[], final  List<String> attachedContexts = const <String>[]}): _roles = roles,_messages = messages,_diceResults = diceResults,_attachedFileNames = attachedFileNames,_attachedContexts = attachedContexts,super._();
  

@override final  StageLoaded? stage;
@override@JsonKey() final  String stagePath;
 final  Map<String, RoleRunState> _roles;
@override@JsonKey() Map<String, RoleRunState> get roles {
  if (_roles is EqualUnmodifiableMapView) return _roles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_roles);
}

 final  List<Message> _messages;
@override@JsonKey() List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override@JsonKey() final  bool isGenerating;
@override@JsonKey() final  String streamingContent;
@override@JsonKey() final  String lastError;
 final  List<DiceResult> _diceResults;
@override@JsonKey() List<DiceResult> get diceResults {
  if (_diceResults is EqualUnmodifiableListView) return _diceResults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diceResults);
}

@override@JsonKey() final  String lastRollInfo;
 final  List<String> _attachedFileNames;
@override@JsonKey() List<String> get attachedFileNames {
  if (_attachedFileNames is EqualUnmodifiableListView) return _attachedFileNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachedFileNames);
}

 final  List<String> _attachedContexts;
@override@JsonKey() List<String> get attachedContexts {
  if (_attachedContexts is EqualUnmodifiableListView) return _attachedContexts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachedContexts);
}


/// Create a copy of StageNarrativeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StageNarrativeStateCopyWith<_StageNarrativeState> get copyWith => __$StageNarrativeStateCopyWithImpl<_StageNarrativeState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StageNarrativeState&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.stagePath, stagePath) || other.stagePath == stagePath)&&const DeepCollectionEquality().equals(other._roles, _roles)&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.isGenerating, isGenerating) || other.isGenerating == isGenerating)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&const DeepCollectionEquality().equals(other._diceResults, _diceResults)&&(identical(other.lastRollInfo, lastRollInfo) || other.lastRollInfo == lastRollInfo)&&const DeepCollectionEquality().equals(other._attachedFileNames, _attachedFileNames)&&const DeepCollectionEquality().equals(other._attachedContexts, _attachedContexts));
}


@override
int get hashCode => Object.hash(runtimeType,stage,stagePath,const DeepCollectionEquality().hash(_roles),const DeepCollectionEquality().hash(_messages),isGenerating,streamingContent,lastError,const DeepCollectionEquality().hash(_diceResults),lastRollInfo,const DeepCollectionEquality().hash(_attachedFileNames),const DeepCollectionEquality().hash(_attachedContexts));

@override
String toString() {
  return 'StageNarrativeState(stage: $stage, stagePath: $stagePath, roles: $roles, messages: $messages, isGenerating: $isGenerating, streamingContent: $streamingContent, lastError: $lastError, diceResults: $diceResults, lastRollInfo: $lastRollInfo, attachedFileNames: $attachedFileNames, attachedContexts: $attachedContexts)';
}


}

/// @nodoc
abstract mixin class _$StageNarrativeStateCopyWith<$Res> implements $StageNarrativeStateCopyWith<$Res> {
  factory _$StageNarrativeStateCopyWith(_StageNarrativeState value, $Res Function(_StageNarrativeState) _then) = __$StageNarrativeStateCopyWithImpl;
@override @useResult
$Res call({
 StageLoaded? stage, String stagePath, Map<String, RoleRunState> roles, List<Message> messages, bool isGenerating, String streamingContent, String lastError, List<DiceResult> diceResults, String lastRollInfo, List<String> attachedFileNames, List<String> attachedContexts
});




}
/// @nodoc
class __$StageNarrativeStateCopyWithImpl<$Res>
    implements _$StageNarrativeStateCopyWith<$Res> {
  __$StageNarrativeStateCopyWithImpl(this._self, this._then);

  final _StageNarrativeState _self;
  final $Res Function(_StageNarrativeState) _then;

/// Create a copy of StageNarrativeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stage = freezed,Object? stagePath = null,Object? roles = null,Object? messages = null,Object? isGenerating = null,Object? streamingContent = null,Object? lastError = null,Object? diceResults = null,Object? lastRollInfo = null,Object? attachedFileNames = null,Object? attachedContexts = null,}) {
  return _then(_StageNarrativeState(
stage: freezed == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as StageLoaded?,stagePath: null == stagePath ? _self.stagePath : stagePath // ignore: cast_nullable_to_non_nullable
as String,roles: null == roles ? _self._roles : roles // ignore: cast_nullable_to_non_nullable
as Map<String, RoleRunState>,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,isGenerating: null == isGenerating ? _self.isGenerating : isGenerating // ignore: cast_nullable_to_non_nullable
as bool,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,diceResults: null == diceResults ? _self._diceResults : diceResults // ignore: cast_nullable_to_non_nullable
as List<DiceResult>,lastRollInfo: null == lastRollInfo ? _self.lastRollInfo : lastRollInfo // ignore: cast_nullable_to_non_nullable
as String,attachedFileNames: null == attachedFileNames ? _self._attachedFileNames : attachedFileNames // ignore: cast_nullable_to_non_nullable
as List<String>,attachedContexts: null == attachedContexts ? _self._attachedContexts : attachedContexts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
