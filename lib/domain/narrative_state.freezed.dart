// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'narrative_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NarrativeState {

 Contract get contract; String get sourceFileName; List<Message> get messages; Map<String, StateValue> get currentState; List<Memory> get memories; List<HistoryEntry> get history; bool get isGenerating; String get streamingContent; String get lastError; List<String> get attachedFileNames; List<String> get attachedContexts;
/// Create a copy of NarrativeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NarrativeStateCopyWith<NarrativeState> get copyWith => _$NarrativeStateCopyWithImpl<NarrativeState>(this as NarrativeState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NarrativeState&&(identical(other.contract, contract) || other.contract == contract)&&(identical(other.sourceFileName, sourceFileName) || other.sourceFileName == sourceFileName)&&const DeepCollectionEquality().equals(other.messages, messages)&&const DeepCollectionEquality().equals(other.currentState, currentState)&&const DeepCollectionEquality().equals(other.memories, memories)&&const DeepCollectionEquality().equals(other.history, history)&&(identical(other.isGenerating, isGenerating) || other.isGenerating == isGenerating)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&const DeepCollectionEquality().equals(other.attachedFileNames, attachedFileNames)&&const DeepCollectionEquality().equals(other.attachedContexts, attachedContexts));
}


@override
int get hashCode => Object.hash(runtimeType,contract,sourceFileName,const DeepCollectionEquality().hash(messages),const DeepCollectionEquality().hash(currentState),const DeepCollectionEquality().hash(memories),const DeepCollectionEquality().hash(history),isGenerating,streamingContent,lastError,const DeepCollectionEquality().hash(attachedFileNames),const DeepCollectionEquality().hash(attachedContexts));

@override
String toString() {
  return 'NarrativeState(contract: $contract, sourceFileName: $sourceFileName, messages: $messages, currentState: $currentState, memories: $memories, history: $history, isGenerating: $isGenerating, streamingContent: $streamingContent, lastError: $lastError, attachedFileNames: $attachedFileNames, attachedContexts: $attachedContexts)';
}


}

/// @nodoc
abstract mixin class $NarrativeStateCopyWith<$Res>  {
  factory $NarrativeStateCopyWith(NarrativeState value, $Res Function(NarrativeState) _then) = _$NarrativeStateCopyWithImpl;
@useResult
$Res call({
 Contract contract, String sourceFileName, List<Message> messages, Map<String, StateValue> currentState, List<Memory> memories, List<HistoryEntry> history, bool isGenerating, String streamingContent, String lastError, List<String> attachedFileNames, List<String> attachedContexts
});


$ContractCopyWith<$Res> get contract;

}
/// @nodoc
class _$NarrativeStateCopyWithImpl<$Res>
    implements $NarrativeStateCopyWith<$Res> {
  _$NarrativeStateCopyWithImpl(this._self, this._then);

  final NarrativeState _self;
  final $Res Function(NarrativeState) _then;

/// Create a copy of NarrativeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? contract = null,Object? sourceFileName = null,Object? messages = null,Object? currentState = null,Object? memories = null,Object? history = null,Object? isGenerating = null,Object? streamingContent = null,Object? lastError = null,Object? attachedFileNames = null,Object? attachedContexts = null,}) {
  return _then(_self.copyWith(
contract: null == contract ? _self.contract : contract // ignore: cast_nullable_to_non_nullable
as Contract,sourceFileName: null == sourceFileName ? _self.sourceFileName : sourceFileName // ignore: cast_nullable_to_non_nullable
as String,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,currentState: null == currentState ? _self.currentState : currentState // ignore: cast_nullable_to_non_nullable
as Map<String, StateValue>,memories: null == memories ? _self.memories : memories // ignore: cast_nullable_to_non_nullable
as List<Memory>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<HistoryEntry>,isGenerating: null == isGenerating ? _self.isGenerating : isGenerating // ignore: cast_nullable_to_non_nullable
as bool,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,attachedFileNames: null == attachedFileNames ? _self.attachedFileNames : attachedFileNames // ignore: cast_nullable_to_non_nullable
as List<String>,attachedContexts: null == attachedContexts ? _self.attachedContexts : attachedContexts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of NarrativeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContractCopyWith<$Res> get contract {
  
  return $ContractCopyWith<$Res>(_self.contract, (value) {
    return _then(_self.copyWith(contract: value));
  });
}
}


/// Adds pattern-matching-related methods to [NarrativeState].
extension NarrativeStatePatterns on NarrativeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NarrativeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NarrativeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NarrativeState value)  $default,){
final _that = this;
switch (_that) {
case _NarrativeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NarrativeState value)?  $default,){
final _that = this;
switch (_that) {
case _NarrativeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Contract contract,  String sourceFileName,  List<Message> messages,  Map<String, StateValue> currentState,  List<Memory> memories,  List<HistoryEntry> history,  bool isGenerating,  String streamingContent,  String lastError,  List<String> attachedFileNames,  List<String> attachedContexts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NarrativeState() when $default != null:
return $default(_that.contract,_that.sourceFileName,_that.messages,_that.currentState,_that.memories,_that.history,_that.isGenerating,_that.streamingContent,_that.lastError,_that.attachedFileNames,_that.attachedContexts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Contract contract,  String sourceFileName,  List<Message> messages,  Map<String, StateValue> currentState,  List<Memory> memories,  List<HistoryEntry> history,  bool isGenerating,  String streamingContent,  String lastError,  List<String> attachedFileNames,  List<String> attachedContexts)  $default,) {final _that = this;
switch (_that) {
case _NarrativeState():
return $default(_that.contract,_that.sourceFileName,_that.messages,_that.currentState,_that.memories,_that.history,_that.isGenerating,_that.streamingContent,_that.lastError,_that.attachedFileNames,_that.attachedContexts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Contract contract,  String sourceFileName,  List<Message> messages,  Map<String, StateValue> currentState,  List<Memory> memories,  List<HistoryEntry> history,  bool isGenerating,  String streamingContent,  String lastError,  List<String> attachedFileNames,  List<String> attachedContexts)?  $default,) {final _that = this;
switch (_that) {
case _NarrativeState() when $default != null:
return $default(_that.contract,_that.sourceFileName,_that.messages,_that.currentState,_that.memories,_that.history,_that.isGenerating,_that.streamingContent,_that.lastError,_that.attachedFileNames,_that.attachedContexts);case _:
  return null;

}
}

}

/// @nodoc


class _NarrativeState extends NarrativeState {
  const _NarrativeState({required this.contract, this.sourceFileName = 'faust.meph', final  List<Message> messages = const <Message>[], final  Map<String, StateValue> currentState = const <String, StateValue>{}, final  List<Memory> memories = const <Memory>[], final  List<HistoryEntry> history = const <HistoryEntry>[], this.isGenerating = false, this.streamingContent = '', this.lastError = '', final  List<String> attachedFileNames = const <String>[], final  List<String> attachedContexts = const <String>[]}): _messages = messages,_currentState = currentState,_memories = memories,_history = history,_attachedFileNames = attachedFileNames,_attachedContexts = attachedContexts,super._();
  

@override final  Contract contract;
@override@JsonKey() final  String sourceFileName;
 final  List<Message> _messages;
@override@JsonKey() List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

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

@override@JsonKey() final  bool isGenerating;
@override@JsonKey() final  String streamingContent;
@override@JsonKey() final  String lastError;
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


/// Create a copy of NarrativeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NarrativeStateCopyWith<_NarrativeState> get copyWith => __$NarrativeStateCopyWithImpl<_NarrativeState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NarrativeState&&(identical(other.contract, contract) || other.contract == contract)&&(identical(other.sourceFileName, sourceFileName) || other.sourceFileName == sourceFileName)&&const DeepCollectionEquality().equals(other._messages, _messages)&&const DeepCollectionEquality().equals(other._currentState, _currentState)&&const DeepCollectionEquality().equals(other._memories, _memories)&&const DeepCollectionEquality().equals(other._history, _history)&&(identical(other.isGenerating, isGenerating) || other.isGenerating == isGenerating)&&(identical(other.streamingContent, streamingContent) || other.streamingContent == streamingContent)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&const DeepCollectionEquality().equals(other._attachedFileNames, _attachedFileNames)&&const DeepCollectionEquality().equals(other._attachedContexts, _attachedContexts));
}


@override
int get hashCode => Object.hash(runtimeType,contract,sourceFileName,const DeepCollectionEquality().hash(_messages),const DeepCollectionEquality().hash(_currentState),const DeepCollectionEquality().hash(_memories),const DeepCollectionEquality().hash(_history),isGenerating,streamingContent,lastError,const DeepCollectionEquality().hash(_attachedFileNames),const DeepCollectionEquality().hash(_attachedContexts));

@override
String toString() {
  return 'NarrativeState(contract: $contract, sourceFileName: $sourceFileName, messages: $messages, currentState: $currentState, memories: $memories, history: $history, isGenerating: $isGenerating, streamingContent: $streamingContent, lastError: $lastError, attachedFileNames: $attachedFileNames, attachedContexts: $attachedContexts)';
}


}

/// @nodoc
abstract mixin class _$NarrativeStateCopyWith<$Res> implements $NarrativeStateCopyWith<$Res> {
  factory _$NarrativeStateCopyWith(_NarrativeState value, $Res Function(_NarrativeState) _then) = __$NarrativeStateCopyWithImpl;
@override @useResult
$Res call({
 Contract contract, String sourceFileName, List<Message> messages, Map<String, StateValue> currentState, List<Memory> memories, List<HistoryEntry> history, bool isGenerating, String streamingContent, String lastError, List<String> attachedFileNames, List<String> attachedContexts
});


@override $ContractCopyWith<$Res> get contract;

}
/// @nodoc
class __$NarrativeStateCopyWithImpl<$Res>
    implements _$NarrativeStateCopyWith<$Res> {
  __$NarrativeStateCopyWithImpl(this._self, this._then);

  final _NarrativeState _self;
  final $Res Function(_NarrativeState) _then;

/// Create a copy of NarrativeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? contract = null,Object? sourceFileName = null,Object? messages = null,Object? currentState = null,Object? memories = null,Object? history = null,Object? isGenerating = null,Object? streamingContent = null,Object? lastError = null,Object? attachedFileNames = null,Object? attachedContexts = null,}) {
  return _then(_NarrativeState(
contract: null == contract ? _self.contract : contract // ignore: cast_nullable_to_non_nullable
as Contract,sourceFileName: null == sourceFileName ? _self.sourceFileName : sourceFileName // ignore: cast_nullable_to_non_nullable
as String,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,currentState: null == currentState ? _self._currentState : currentState // ignore: cast_nullable_to_non_nullable
as Map<String, StateValue>,memories: null == memories ? _self._memories : memories // ignore: cast_nullable_to_non_nullable
as List<Memory>,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<HistoryEntry>,isGenerating: null == isGenerating ? _self.isGenerating : isGenerating // ignore: cast_nullable_to_non_nullable
as bool,streamingContent: null == streamingContent ? _self.streamingContent : streamingContent // ignore: cast_nullable_to_non_nullable
as String,lastError: null == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String,attachedFileNames: null == attachedFileNames ? _self._attachedFileNames : attachedFileNames // ignore: cast_nullable_to_non_nullable
as List<String>,attachedContexts: null == attachedContexts ? _self._attachedContexts : attachedContexts // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of NarrativeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ContractCopyWith<$Res> get contract {
  
  return $ContractCopyWith<$Res>(_self.contract, (value) {
    return _then(_self.copyWith(contract: value));
  });
}
}

// dart format on
