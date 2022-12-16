part of mpv_bindings;

/// Mpv client API.
class MpvClient {
  /// MpvClient Map.
  /// Lookup for callback events.
  static final Map<int, MpvClient> _mpvClientMap = {};

  /// This callback is invoked from any mpv thread (but possibly also
  /// recursively from a thread that is calling the mpv API).
  static void _wakeup(Pointer<Void> key) {
    final mpvClient = _mpvClientMap[key.cast<IntPtr>().value];
    if (mpvClient != null) {
      mpvClient._onEvents();
    }
  }

  /// Mpv bindings.
  final MpvBindings _bindings;

  /// Client context used by the client API. Every client has its own private
  /// handle.
  final Pointer<mpv_handle> handle;

  late final Pointer<IntPtr> _key;

  /// Create mpv client.
  MpvClient({
    MpvBindings? bindings,
  })  : _bindings = bindings ?? MpvLib.bindings,
        handle = (bindings ?? MpvLib.bindings).mpv_create() {
    _register();
  }

  /// Create mpv client with handle.
  MpvClient.handle({
    MpvBindings? bindings,
    required this.handle,
  }) : _bindings = bindings ?? MpvLib.bindings {
    _register();
  }

  /// Event listeners.
  final Map<int, List<MpvEventCallback>> _eventListeners = {};

  /// Add event listener.
  /// [eventId] See [mpv_event_id].
  /// [listener] Event listener for eventId.
  void addEventListener(int eventId, MpvEventCallback listener) {
    if (!_eventListeners.containsKey(eventId)) {
      _eventListeners[eventId] = [];
    }
    _eventListeners[eventId]!.add(listener);
  }

  /// Remove event listener.
  /// [eventId] See [mpv_event_id].
  /// [listener] Event listener for eventId.
  void removeEventListener(int eventId, MpvEventCallback listener) {
    if (_eventListeners.containsKey(eventId)) {
      _eventListeners[eventId]!.remove(listener);
    }
  }

  /// Register mpv client.
  void _register() {
    _key = malloc.call<IntPtr>()..value = handle.address;
    _mpvClientMap[_key.value] = this;
    _setWakeupCallback();
  }

  /// Unregister mpv client.
  void _unregister() {
    _mpvClientMap.remove(_key.value);
    malloc.free(_key);
    _eventListeners.clear();
  }

  /// Handle mpv error code.
  void _handleErrorCode(int error) {
    if (error != 0) {
      throw MpvException(code: error, message: errorString(error));
    }
  }

  /// Return the MPV_CLIENT_API_VERSION the mpv source has been compiled with.
  int get apiVersion {
    return _bindings.mpv_client_api_version();
  }

  /// Return a string describing the error. For unknown errors, the string
  /// "unknown error" is returned.
  ///
  /// @param [error] error number, see enum mpv_error
  /// return A static string describing the error. The string is completely
  /// static, i.e. doesn't need to be deallocated, and is valid forever.
  String errorString(int error) {
    return _bindings.mpv_error_string(error).toDartString();
  }

  /// General function to deallocate memory returned by some of the API functions.
  /// Call this only if it's explicitly documented as allowed. Calling this on
  /// mpv memory not owned by the caller will lead to undefined behavior.
  ///
  /// @param [data] A valid pointer returned by the API, or NULL.
  void free(Pointer data) {
    _bindings.mpv_free(data.cast<Void>());
  }

  /// Return the name of this client handle. Every client has its own unique
  /// name, which is mostly used for user interface purposes.
  ///
  /// The client name. The string is read-only and is valid until the
  /// mpv_handle is destroyed.
  String get name {
    return _bindings.mpv_client_name(handle).toDartString();
  }

  /// Return the ID of this client handle. Every client has its own unique ID. This
  /// ID is never reused by the core, even if the mpv_handle at hand gets destroyed
  /// and new handles get allocated.
  ///
  /// IDs are never 0 or negative.
  ///
  /// Some mpv APIs (not necessarily all) accept a name in the form "@<id>" in
  /// addition of the proper mpv_client_name(), where "<id>" is the ID in decimal
  /// form (e.g. "@123"). For example, the "script-message-to" command takes the
  /// client name as first argument, but also accepts the client ID formatted in
  /// this manner.
  ///
  /// return The client ID.
  int get id {
    return _bindings.mpv_client_id(handle);
  }

  /// Initialize an uninitialized mpv instance. If the mpv instance is already
  /// running, an error is returned.
  ///
  /// This function needs to be called to make full use of the client API if the
  /// client API handle was created with mpv_create().
  ///
  /// Only the following options are required to be set _before_ mpv_initialize():
  ///      - options which are only read at initialization time:
  ///        - config
  ///        - config-dir
  ///        - input-conf
  ///        - load-scripts
  ///        - script
  ///        - player-operation-mode
  ///        - input-app-events (OSX)
  ///      - all encoding mode options
  void initialize() {
    _handleErrorCode(_bindings.mpv_initialize(handle));
  }

  /// Disconnect and destroy the mpv_handle. ctx will be deallocated with this
  /// API call.
  ///
  /// If the last mpv_handle is detached, the core player is destroyed. In
  /// addition, if there are only weak mpv_handles (such as created by
  /// mpv_create_weak_client() or internal scripts), these mpv_handles will
  /// be sent MPV_EVENT_SHUTDOWN. This function may block until these clients
  /// have responded to the shutdown event, and the core is finally destroyed.
  void destroy() {
    _bindings.mpv_destroy(handle);
    _unregister();
  }

  /// Similar to mpv_destroy(), but brings the player and all clients down
  /// as well, and waits until all of them are destroyed. This function blocks. The
  /// advantage over mpv_destroy() is that while mpv_destroy() merely
  /// detaches the client handle from the player, this function quits the player,
  /// waits until all other clients are destroyed (i.e. all mpv_handles are
  /// detached), and also waits for the final termination of the player.
  ///
  /// Since mpv_destroy() is called somewhere on the way, it's not safe to
  /// call other functions concurrently on the same context.
  ///
  /// Since mpv client API version 1.29:
  ///  The first call on any mpv_handle will block until the core is destroyed.
  ///  This means it will wait until other mpv_handle have been destroyed. If you
  ///  want asynchronous destruction, just run the "quit" command, and then react
  ///  to the MPV_EVENT_SHUTDOWN event.
  ///  If another mpv_handle already called mpv_terminate_destroy(), this call will
  ///  not actually block. It will destroy the mpv_handle, and exit immediately,
  ///  while other mpv_handles might still be uninitializing.
  ///
  /// Before mpv client API version 1.29:
  ///  If this is called on a mpv_handle that was not created with mpv_create(),
  ///  this function will merely send a quit command and then call
  ///  mpv_destroy(), without waiting for the actual shutdown.
  void terminateDestroy() {
    _bindings.mpv_terminate_destroy(handle);
    _unregister();
  }

  /// Create a new client handle connected to the same player core as ctx. This
  /// context has its own event queue, its own mpv_request_event() state, its own
  /// mpv_request_log_messages() state, its own set of observed properties, and
  /// its own state for asynchronous operations. Otherwise, everything is shared.
  ///
  /// This handle should be destroyed with mpv_destroy() if no longer
  /// needed. The core will live as long as there is at least 1 handle referencing
  /// it. Any handle can make the core quit, which will result in every handle
  /// receiving MPV_EVENT_SHUTDOWN.
  ///
  /// This function can not be called before the main handle was initialized with
  /// mpv_initialize(). The new handle is always initialized, unless ctx=NULL was
  /// passed.
  ///
  /// @param [name] The client name. This will be returned by mpv_client_name(). If
  ///             the name is already in use, or contains non-alphanumeric
  ///             characters (other than '_'), the name is modified to fit.
  ///             If NULL, an arbitrary name is automatically chosen.
  /// return a new handle, or NULL on error
  MpvClient createClient(String name) {
    final ctx = _bindings.mpv_create_client(handle, name.toNativeChar());
    return MpvClient.handle(handle: ctx, bindings: _bindings);
  }

  /// This is the same as [createClient], but the created mpv_handle is
  /// treated as a weak reference. If all mpv_handles referencing a core are
  /// weak references, the core is automatically destroyed. (This still goes
  /// through normal uninit of course. Effectively, if the last non-weak mpv_handle
  /// is destroyed, then the weak mpv_handles receive MPV_EVENT_SHUTDOWN and are
  /// asked to terminate as well.)
  ///
  /// Note if you want to use this like refcounting: you have to be aware that
  /// mpv_terminate_destroy() _and_ mpv_destroy() for the last non-weak
  /// mpv_handle will block until all weak mpv_handles are destroyed.
  MpvClient createWeakClient(String name) {
    final ctx = _bindings.mpv_create_weak_client(handle, name.toNativeChar());
    return MpvClient.handle(handle: ctx, bindings: _bindings);
  }

  /// Load a config file. This loads and parses the file, and sets every entry in
  /// the config file's default section as if mpv_set_option_string() is called.
  ///
  /// The filename should be an absolute path. If it isn't, the actual path used
  /// is unspecified. (Note: an absolute path starts with '/' on UNIX.) If the
  /// file wasn't found, MPV_ERROR_INVALID_PARAMETER is returned.
  ///
  /// If a fatal error happens when parsing a config file, MPV_ERROR_OPTION_ERROR
  /// is returned. Errors when setting options as well as other types or errors
  /// are ignored (even if options do not exist). You can still try to capture
  /// the resulting error messages with mpv_request_log_messages(). Note that it's
  /// possible that some options were successfully set even if any of these errors
  /// happen.
  ///
  /// @param [filename] absolute path to the config file on the local filesystem
  void loadConfigFile(String filename) {
    _handleErrorCode(
        _bindings.mpv_load_config_file(handle, filename.toNativeChar()));
  }

  /// Return the internal time in microseconds. This has an arbitrary start offset,
  /// but will never wrap or go backwards.
  ///
  /// Note that this is always the real time, and doesn't necessarily have to do
  /// with playback time. For example, playback could go faster or slower due to
  /// playback speed, or due to playback being paused. Use the "time-pos" property
  /// instead to get the playback status.
  ///
  /// Unlike other libmpv APIs, this can be called at absolutely any time (even
  /// within wakeup callbacks), as long as the context is valid.
  ///
  /// Safe to be called from mpv render API threads.
  int getTimeUs() {
    return _bindings.mpv_get_time_us(handle);
  }

  /// Frees any data referenced by the node. It doesn't free the node itself.
  /// Call this only if the mpv client API set the node. If you constructed the
  /// node yourself (manually), you have to free it yourself.
  ///
  /// If node->format is MPV_FORMAT_NONE, this call does nothing. Likewise, if
  /// the client API sets a node with this format, this function doesn't need to
  /// be called. (This is just a clarification that there's no danger of anything
  /// strange happening in these cases.)
  void freeNodeContents(Pointer<mpv_node> node) {
    _bindings.mpv_free_node_contents(node);
  }

  /// Set an option. Note that you can't normally set options during runtime. It
  /// works in uninitialized state (see mpv_create()), and in some cases in at
  /// runtime.
  ///
  /// Using a format other than MPV_FORMAT_NODE is equivalent to constructing a
  /// mpv_node with the given format and data, and passing the mpv_node to this
  /// function.
  ///
  /// Note: this is semi-deprecated. For most purposes, this is not needed anymore.
  ///       Starting with mpv version 0.21.0 (version 1.23) most options can be set
  ///       with mpv_set_property() (and related functions), and even before
  ///       mpv_initialize(). In some obscure corner cases, using this function
  ///       to set options might still be required (see
  ///       "Inconsistencies between options and properties" in the manpage). Once
  ///       these are resolved, the option setting functions might be fully
  ///       deprecated.
  ///
  /// @param [name] Option name. This is the same as on the mpv command line, but
  ///             without the leading "--".
  /// @param[in] [data] Option value (according to the format).
  void setOption(String name, dynamic data) {
    _handleErrorCode(_bindings.mpv_set_option(handle, name.toNativeChar(),
        mpv_format.MPV_FORMAT_NODE, MpvNode.toNode(data).cast<Void>()));
  }

  /// Convenience function to set an option to a string value. This is like
  /// calling mpv_set_option() with MPV_FORMAT_STRING.
  void setOptionString(String name, String data) {
    _handleErrorCode(_bindings.mpv_set_property_string(
        handle, name.toNativeChar(), data.toNativeChar()));
  }

  /// Send a command to the player. Commands are the same as those used in
  /// input.conf, except that this function takes parameters in a pre-split
  /// form.
  ///
  /// The commands and their parameters are documented in input.rst.
  ///
  /// Does not use OSD and string expansion by default (unlike mpv_command_string()
  /// and input.conf).
  ///
  /// @param[in] [args] NULL-terminated list of strings. Usually, the first item
  ///                 is the command, and the following items are arguments.
  void command(List<String> args) {
    _handleErrorCode(_bindings.mpv_command(handle, args.toNativeCharList()));
  }

  /// Same as mpv_command(), but allows passing structured data in any format.
  /// In particular, calling mpv_command() is exactly like calling
  /// mpv_command_node() with the format set to MPV_FORMAT_NODE_ARRAY, and
  /// every arg passed in order as MPV_FORMAT_STRING.
  ///
  /// Does not use OSD and string expansion by default.
  ///
  /// The args argument can have one of the following formats:
  ///
  /// MPV_FORMAT_NODE_ARRAY:
  ///      Positional arguments. Each entry is an argument using an arbitrary
  ///      format (the format must be compatible to the used command). Usually,
  ///      the first item is the command name (as MPV_FORMAT_STRING). The order
  ///      of arguments is as documented in each command description.
  ///
  /// MPV_FORMAT_NODE_MAP:
  ///      Named arguments. This requires at least an entry with the key "name"
  ///      to be present, which must be a string, and contains the command name.
  ///      The special entry "_flags" is optional, and if present, must be an
  ///      array of strings, each being a command prefix to apply. All other
  ///      entries are interpreted as arguments. They must use the argument names
  ///      as documented in each command description. Some commands do not
  ///      support named arguments at all, and must use MPV_FORMAT_NODE_ARRAY.
  ///
  /// @param[in] [args] mpv_node with format set to one of the values documented
  ///                 above (see there for details)
  /// @return [result] Optional, pass NULL if unused. If not NULL, and if the
  ///                    function succeeds, this is set to command-specific return
  ///                    data. You must call mpv_free_node_contents() to free it
  ///                    (again, only if the command actually succeeds).
  ///                    Not many commands actually use this at all.
  T? commandNode<T>(List args) {
    final result = malloc.call<mpv_node>();
    final nodeList = MpvNode.toNodeList(args);
    final argsList = nodeList.ref.values;
    malloc.free(nodeList);
    try {
      _handleErrorCode(_bindings.mpv_command_node(handle, argsList, result));
      return MpvNode.toData<T>(result);
    } catch (_) {
      rethrow;
    } finally {
      freeNodeContents(result);
    }
  }

  /// This is essentially identical to mpv_command() but it also returns a result.
  ///
  /// Does not use OSD and string expansion by default.
  ///
  /// @param[in] [args] NULL-terminated list of strings. Usually, the first item
  ///                 is the command, and the following items are arguments.
  /// @return [result] Optional, pass NULL if unused. If not NULL, and if the
  ///                    function succeeds, this is set to command-specific return
  ///                    data. You must call mpv_free_node_contents() to free it
  ///                    (again, only if the command actually succeeds).
  ///                    Not many commands actually use this at all.
  T? commandRet<T>(List<String> args) {
    final result = malloc.call<mpv_node>();
    try {
      _handleErrorCode(
          _bindings.mpv_command_ret(handle, args.toNativeCharList(), result));
      return MpvNode.toData<T>(result);
    } catch (_) {
      rethrow;
    } finally {
      freeNodeContents(result);
    }
  }

  /// Same as mpv_command, but use input.conf parsing for splitting arguments.
  /// This is slightly simpler, but also more error prone, since arguments may
  /// need quoting/escaping.
  ///
  /// This also has OSD and string expansion enabled by default.
  void commandString(String args) {
    _handleErrorCode(_bindings.mpv_command_string(handle, args.toNativeChar()));
  }

  /// Same as mpv_command, but run the command asynchronously.
  ///
  /// Commands are executed asynchronously. You will receive a
  /// MPV_EVENT_COMMAND_REPLY event. This event will also have an
  /// error code set if running the command failed. For commands that
  /// return data, the data is put into mpv_event_command.result.
  ///
  /// The only case when you do not receive an event is when the function call
  /// itself fails. This happens only if parsing the command itself (or otherwise
  /// validating it) fails, i.e. the return code of the API call is not 0 or
  /// positive.
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param [replyUserdata] the value mpv_event.reply_userdata of the reply will
  ///                       be set to (see section about asynchronous calls)
  /// @param [args] NULL-terminated list of strings (see mpv_command())
  void commandAsync(int replyUserdata, List<String> args) {
    _handleErrorCode(_bindings.mpv_command_async(
        handle, replyUserdata, args.toNativeCharList()));
  }

  /// Same as mpv_command_node(), but run it asynchronously. Basically, this
  /// function is to mpv_command_node() what mpv_command_async() is to
  /// mpv_command().
  ///
  /// See mpv_command_async() for details.
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param [replyUserdata] the value mpv_event.reply_userdata of the reply will
  ///                       be set to (see section about asynchronous calls)
  /// @param [args] as in mpv_command_node()
  void commandNodeAsync(int replyUserdata, List args) {
    final nodeList = MpvNode.toNodeList(args);
    final argsList = nodeList.ref.values;
    malloc.free(nodeList);
    _handleErrorCode(
        _bindings.mpv_command_node_async(handle, replyUserdata, argsList));
  }

  /// Signal to all async requests with the matching ID to abort. This affects
  /// the following API calls:
  ///
  ///      mpv_command_async
  ///      mpv_command_node_async
  ///
  /// All of these functions take a reply_userdata parameter. This API function
  /// tells all requests with the matching reply_userdata value to try to return
  /// as soon as possible. If there are multiple requests with matching ID, it
  /// aborts all of them.
  ///
  /// This API function is mostly asynchronous itself. It will not wait until the
  /// command is aborted. Instead, the command will terminate as usual, but with
  /// some work not done. How this is signaled depends on the specific command (for
  /// example, the "subprocess" command will indicate it by "killed_by_us" set to
  /// true in the result). How long it takes also depends on the situation. The
  /// aborting process is completely asynchronous.
  ///
  /// Not all commands may support this functionality. In this case, this function
  /// will have no effect. The same is true if the request using the passed
  /// reply_userdata has already terminated, has not been started yet, or was
  /// never in use at all.
  ///
  /// You have to be careful of race conditions: the time during which the abort
  /// request will be effective is _after_ e.g. mpv_command_async() has returned,
  /// and before the command has signaled completion with MPV_EVENT_COMMAND_REPLY.
  ///
  /// @param [replyUserdata] ID of the request to be aborted (see above)
  void abortAsyncCommand(int replyUserdata) {
    _bindings.mpv_abort_async_command(handle, replyUserdata);
  }

  /// Set a property to a given value. Properties are essentially variables which
  /// can be queried or set at runtime. For example, writing to the pause property
  /// will actually pause or unpause playback.
  ///
  /// If the format doesn't match with the internal format of the property, access
  /// usually will fail with MPV_ERROR_PROPERTY_FORMAT. In some cases, the data
  /// is automatically converted and access succeeds. For example, MPV_FORMAT_INT64
  /// is always converted to MPV_FORMAT_DOUBLE, and access using MPV_FORMAT_STRING
  /// usually invokes a string parser. The same happens when calling this function
  /// with MPV_FORMAT_NODE: the underlying format may be converted to another
  /// type if possible.
  ///
  /// Using a format other than MPV_FORMAT_NODE is equivalent to constructing a
  /// mpv_node with the given format and data, and passing the mpv_node to this
  /// function. (Before API version 1.21, this was different.)
  ///
  /// Note: starting with mpv 0.21.0 (client API version 1.23), this can be used to
  ///       set options in general. It even can be used before mpv_initialize()
  ///       has been called. If called before mpv_initialize(), setting properties
  ///       not backed by options will result in MPV_ERROR_PROPERTY_UNAVAILABLE.
  ///       In some cases, properties and options still conflict. In these cases,
  ///       mpv_set_property() accesses the options before mpv_initialize(), and
  ///       the properties after mpv_initialize(). These conflicts will be removed
  ///       in mpv 0.23.0. See mpv_set_option() for further remarks.
  ///
  /// @param [name] The property name. See input.rst for a list of properties.
  /// @param[in] [data] Option value.
  void setProperty(String name, dynamic data) {
    _handleErrorCode(_bindings.mpv_set_property(handle, name.toNativeChar(),
        mpv_format.MPV_FORMAT_NODE, MpvNode.toNode(data).cast<Void>()));
  }

  /// Convenience function to set a property to a string value.
  ///
  /// This is like calling mpv_set_property() with MPV_FORMAT_STRING.
  void setPropertyString(String name, String data) {
    _handleErrorCode(_bindings.mpv_set_property_string(
        handle, name.toNativeChar(), data.toNativeChar()));
  }

  /// Set a property asynchronously. You will receive the result of the operation
  /// as MPV_EVENT_SET_PROPERTY_REPLY event. The mpv_event.error field will contain
  /// the result status of the operation. Otherwise, this function is similar to
  /// mpv_set_property().
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param [replyUserdata] see section about asynchronous calls
  /// @param [name] The property name.
  /// @param[in] data Option value. The value will be copied by the function. It
  ///                 will never be modified by the client API.
  void setPropertyAsync(int replyUserdata, String name, dynamic data) {
    return _handleErrorCode(_bindings.mpv_set_property_async(
        handle,
        replyUserdata,
        name.toNativeChar(),
        mpv_format.MPV_FORMAT_NODE,
        MpvNode.toNode(data).cast<Void>()));
  }

  /// Read the value of the given property.
  ///
  /// If the format doesn't match with the internal format of the property, access
  /// usually will fail with MPV_ERROR_PROPERTY_FORMAT. In some cases, the data
  /// is automatically converted and access succeeds. For example, MPV_FORMAT_INT64
  /// is always converted to MPV_FORMAT_DOUBLE, and access using MPV_FORMAT_STRING
  /// usually invokes a string formatter.
  ///
  /// @param [name] The property name.
  /// @param[out] data Pointer to the variable holding the option value. On
  ///                  success, the variable will be set to a copy of the option
  ///                  value. For formats that require dynamic memory allocation,
  ///                  you can free the value with mpv_free() (strings) or
  ///                  mpv_free_node_contents() (MPV_FORMAT_NODE).
  T? getProperty<T>(String name) {
    final result = malloc.call<mpv_node>();
    try {
      _handleErrorCode(_bindings.mpv_get_property(handle, name.toNativeChar(),
          mpv_format.MPV_FORMAT_NODE, result.cast<Void>()));
      final data = MpvNode.toData<T>(result);
      freeNodeContents(result);
      return data;
    } catch (_) {
      rethrow;
    } finally {
      freeNodeContents(result);
    }
  }

  /// Return the value of the property with the given name as string. This is
  /// equivalent to mpv_get_property() with MPV_FORMAT_STRING.
  ///
  /// See MPV_FORMAT_STRING for character encoding issues.
  ///
  /// On error, NULL is returned. Use mpv_get_property() if you want fine-grained
  /// error reporting.
  ///
  /// @param name The property name.
  /// @return Property value, or NULL if the property can't be retrieved. Free
  ///         the string with mpv_free().
  String getPropertyString(String name) {
    final pointer =
        _bindings.mpv_get_property_string(handle, name.toNativeChar());
    final data = pointer.toDartString();
    free(pointer);
    return data;
  }

  /// Return the property as "OSD" formatted string. This is the same as
  /// mpv_get_property_string, but using MPV_FORMAT_OSD_STRING.
  ///
  /// @return Property value, or NULL if the property can't be retrieved. Free
  ///         the string with mpv_free().
  String getPropertyOSDString(String name) {
    final pointer =
        _bindings.mpv_get_property_osd_string(handle, name.toNativeChar());
    final data = pointer.toDartString();
    free(pointer);
    return data;
  }

  /// Get a property asynchronously. You will receive the result of the operation
  /// as well as the property data with the MPV_EVENT_GET_PROPERTY_REPLY event.
  /// You should check the mpv_event.error field on the reply event.
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param reply_userdata see section about asynchronous calls
  /// @param name The property name.
  /// @param format see enum mpv_format.
  void getPropertyAsync(int replyUserdata, String name, int format) {
    _handleErrorCode(_bindings.mpv_get_property_async(
        handle, replyUserdata, name.toNativeChar(), format));
  }

  /// Get a notification whenever the given property changes. You will receive
  /// updates as MPV_EVENT_PROPERTY_CHANGE. Note that this is not very precise:
  /// for some properties, it may not send updates even if the property changed.
  /// This depends on the property, and it's a valid feature request to ask for
  /// better update handling of a specific property. (For some properties, like
  /// ``clock``, which shows the wall clock, this mechanism doesn't make too
  /// much sense anyway.)
  ///
  /// Property changes are coalesced: the change events are returned only once the
  /// event queue becomes empty (e.g. mpv_wait_event() would block or return
  /// MPV_EVENT_NONE), and then only one event per changed property is returned.
  ///
  /// You always get an initial change notification. This is meant to initialize
  /// the user's state to the current value of the property.
  ///
  /// Normally, change events are sent only if the property value changes according
  /// to the requested format. mpv_event_property will contain the property value
  /// as data member.
  ///
  /// Warning: if a property is unavailable or retrieving it caused an error,
  ///          MPV_FORMAT_NONE will be set in mpv_event_property, even if the
  ///          format parameter was set to a different value. In this case, the
  ///          mpv_event_property.data field is invalid.
  ///
  /// If the property is observed with the format parameter set to MPV_FORMAT_NONE,
  /// you get low-level notifications whether the property _may_ have changed, and
  /// the data member in mpv_event_property will be unset. With this mode, you
  /// will have to determine yourself whether the property really changed. On the
  /// other hand, this mechanism can be faster and uses less resources.
  ///
  /// Observing a property that doesn't exist is allowed. (Although it may still
  /// cause some sporadic change events.)
  ///
  /// Keep in mind that you will get change notifications even if you change a
  /// property yourself. Try to avoid endless feedback loops, which could happen
  /// if you react to the change notifications triggered by your own change.
  ///
  /// Only the mpv_handle on which this was called will receive the property
  /// change events, or can unobserve them.
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param reply_userdata This will be used for the mpv_event.reply_userdata
  ///                       field for the received MPV_EVENT_PROPERTY_CHANGE
  ///                       events. (Also see section about asynchronous calls,
  ///                       although this function is somewhat different from
  ///                       actual asynchronous calls.)
  ///                       If you have no use for this, pass 0.
  ///                       Also see mpv_unobserve_property().
  /// @param name The property name.
  /// @param format see enum mpv_format. Can be MPV_FORMAT_NONE to omit values
  ///               from the change events.
  void getObserveAsync(int replyUserdata, String name, int format) {
    _handleErrorCode(_bindings.mpv_observe_property(
        handle, replyUserdata, name.toNativeChar(), format));
  }

  /// Undo mpv_observe_property(). This will remove all observed properties for
  /// which the given number was passed as reply_userdata to mpv_observe_property.
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param registered_reply_userdata ID that was passed to mpv_observe_property
  /// @return negative value is an error code, >=0 is number of removed properties
  ///         on success (includes the case when 0 were removed)
  int getUnobserveAsync(int replyUserdata) {
    final code = _bindings.mpv_unobserve_property(handle, replyUserdata);
    _handleErrorCode(code);
    return code;
  }

  /// Return a string describing the event. For unknown events, NULL is returned.
  ///
  /// Note that all events actually returned by the API will also yield a non-NULL
  /// string with this function.
  ///
  /// @param event event ID, see see enum mpv_event_id
  /// @return A static string giving a short symbolic name of the event. It
  ///         consists of lower-case alphanumeric characters and can include "-"
  ///         characters. This string is suitable for use in e.g. scripting
  ///         interfaces.
  ///         The string is completely static, i.e. doesn't need to be deallocated,
  ///         and is valid forever.
  String eventName(int event) {
    return _bindings.mpv_event_name(event).toDartString();
  }

  /// Convert the given src event to a mpv_node, and set///dst to the result.///dst
  /// is set to a MPV_FORMAT_NODE_MAP, with fields for corresponding mpv_event and
  /// mpv_event.data/mpv_event_* fields.
  ///
  /// The exact details are not completely documented out of laziness. A start
  /// is located in the "Events" section of the manpage.
  ///
  //////dst may point to newly allocated memory, or pointers in mpv_event. You must
  /// copy the entire mpv_node if you want to reference it after mpv_event becomes
  /// invalid (such as making a new mpv_wait_event() call, or destroying the
  /// mpv_handle from which it was returned). Call mpv_free_node_contents() to free
  /// any memory allocations made by this API function.
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param dst Target. This is not read and fully overwritten. Must be released
  ///            with mpv_free_node_contents(). Do not write to pointers returned
  ///            by it. (On error, this may be left as an empty node.)
  /// @param src The source event. Not modified (it's not const due to the author's
  ///            prejudice of the C version of const).
  T? eventToNode<T>(Pointer<mpv_event> src) {
    final dst = malloc.call<mpv_node>();
    try {
      _handleErrorCode(_bindings.mpv_event_to_node(dst, src));
      final data = MpvNode.toData<T>(dst);
      return data;
    } catch (_) {
      rethrow;
    } finally {
      freeNodeContents(dst);
    }
  }

  /// Enable or disable the given event.
  ///
  /// Some events are enabled by default. Some events can't be disabled.
  ///
  /// (Informational note: currently, all events are enabled by default, except
  ///  MPV_EVENT_TICK.)
  ///
  /// Safe to be called from mpv render API threads.
  ///
  /// @param [event] See enum mpv_event_id.
  /// @param [enable] 1 to enable receiving this event, 0 to disable it.
  void requestEvent(int event, bool enable) {
    _handleErrorCode(
        _bindings.mpv_request_event(handle, event, enable ? 1 : 0));
  }

  /// Enable or disable receiving of log messages. These are the messages the
  /// command line player prints to the terminal. This call sets the minimum
  /// required log level for a message to be received with MPV_EVENT_LOG_MESSAGE.
  ///
  /// @param [minLevel] Minimal log level as string. Valid log levels:
  ///                      no fatal error warn info v debug trace
  ///                  The value "no" disables all messages. This is the default.
  ///                  An exception is the value "terminal-default", which uses the
  ///                  log level as set by the "--msg-level" option. This works
  ///                  even if the terminal is disabled. (Since API version 1.19.)
  ///                  Also see mpv_log_level.
  void requestLogMessages(String minLevel) {
    _handleErrorCode(
        _bindings.mpv_request_log_messages(handle, minLevel.toNativeChar()));
  }

  /// Wait for the next event, or until the timeout expires, or if another thread
  /// makes a call to mpv_wakeup(). Passing 0 as timeout will never wait, and
  /// is suitable for polling.
  ///
  /// The internal event queue has a limited size (per client handle). If you
  /// don't empty the event queue quickly enough with mpv_wait_event(), it will
  /// overflow and silently discard further events. If this happens, making
  /// asynchronous requests will fail as well (with MPV_ERROR_EVENT_QUEUE_FULL).
  ///
  /// Only one thread is allowed to call this on the same mpv_handle at a time.
  /// The API won't complain if more than one thread calls this, but it will cause
  /// race conditions in the client when accessing the shared mpv_event struct.
  /// Note that most other API functions are not restricted by this, and no API
  /// function internally calls mpv_wait_event(). Additionally, concurrent calls
  /// to different mpv_handles are always safe.
  ///
  /// As long as the timeout is 0, this is safe to be called from mpv render API
  /// threads.
  ///
  /// @param [timeout] Timeout in seconds, after which the function returns even if
  ///                no event was received. A MPV_EVENT_NONE is returned on
  ///                timeout. A value of 0 will disable waiting. Negative values
  ///                will wait with an infinite timeout.
  /// @return A struct containing the event ID and other data. The pointer (and
  ///         fields in the struct) stay valid until the next mpv_wait_event()
  ///         call, or until the mpv_handle is destroyed. You must not write to
  ///         the struct, and all memory referenced by it will be automatically
  ///         released by the API on the next mpv_wait_event() call, or when the
  ///         context is destroyed. The return value is never NULL.
  Pointer<mpv_event> waitEvent(double timeout) {
    return _bindings.mpv_wait_event(handle, timeout);
  }

  /// Interrupt the current mpv_wait_event() call. This will wake up the thread
  /// currently waiting in mpv_wait_event(). If no thread is waiting, the next
  /// mpv_wait_event() call will return immediately (this is to avoid lost
  /// wakeups).
  ///
  /// mpv_wait_event() will receive a MPV_EVENT_NONE if it's woken up due to
  /// this call. But note that this dummy event might be skipped if there are
  /// already other events queued. All what counts is that the waiting thread
  /// is woken up at all.
  ///
  /// Safe to be called from mpv render API threads.
  void wakeup() {
    return _bindings.mpv_wakeup(handle);
  }

  /// Set a custom function that should be called when there are new events. Use
  /// this if blocking in mpv_wait_event() to wait for new events is not feasible.
  ///
  /// Keep in mind that the callback will be called from foreign threads. You
  /// must not make any assumptions of the environment, and you must return as
  /// soon as possible (i.e. no long blocking waits). Exiting the callback through
  /// any other means than a normal return is forbidden (no throwing exceptions,
  /// no longjmp() calls). You must not change any local thread state (such as
  /// the C floating point environment).
  ///
  /// You are not allowed to call any client API functions inside of the callback.
  /// In particular, you should not do any processing in the callback, but wake up
  /// another thread that does all the work. The callback is meant strictly for
  /// notification only, and is called from arbitrary core parts of the player,
  /// that make no considerations for reentrant API use or allowing the callee to
  /// spend a lot of time doing other things. Keep in mind that it's also possible
  /// that the callback is called from a thread while a mpv API function is called
  /// (i.e. it can be reentrant).
  ///
  /// In general, the client API expects you to call mpv_wait_event() to receive
  /// notifications, and the wakeup callback is merely a helper utility to make
  /// this easier in certain situations. Note that it's possible that there's
  /// only one wakeup callback invocation for multiple events. You should call
  /// mpv_wait_event() with no timeout until MPV_EVENT_NONE is reached, at which
  /// point the event queue is empty.
  ///
  /// If you actually want to do processing in a callback, spawn a thread that
  /// does nothing but call mpv_wait_event() in a loop and dispatches the result
  /// to a callback.
  ///
  /// Only one wakeup callback can be set.
  ///
  /// @param cb function that should be called if a wakeup is required
  /// @param d arbitrary userdata passed to cb
  void _setWakeupCallback() {
    _bindings.mpv_set_wakeup_callback(
        handle, Pointer.fromFunction(_wakeup), _key.cast<Void>());
  }

  /// Block until all asynchronous requests are done. This affects functions like
  /// mpv_command_async(), which return immediately and return their result as
  /// events.
  ///
  /// This is a helper, and somewhat equivalent to calling mpv_wait_event() in a
  /// loop until all known asynchronous requests have sent their reply as event,
  /// except that the event queue is not emptied.
  ///
  /// In case you called mpv_suspend() before, this will also forcibly reset the
  /// suspend counter of the given handle.
  void waitAsyncRequests() {
    _bindings.mpv_wait_async_requests(handle);
  }

  /// A hook is like a synchronous event that blocks the player. You register
  /// a hook handler with this function. You will get an event, which you need
  /// to handle, and once things are ready, you can let the player continue with
  /// mpv_hook_continue().
  ///
  /// Currently, hooks can't be removed explicitly. But they will be implicitly
  /// removed if the mpv_handle it was registered with is destroyed. This also
  /// continues the hook if it was being handled by the destroyed mpv_handle (but
  /// this should be avoided, as it might mess up order of hook execution).
  ///
  /// Hook handlers are ordered globally by priority and order of registration.
  /// Handlers for the same hook with same priority are invoked in order of
  /// registration (the handler registered first is run first). Handlers with
  /// lower priority are run first (which seems backward).
  ///
  /// See the "Hooks" section in the manpage to see which hooks are currently
  /// defined.
  ///
  /// Some hooks might be reentrant (so you get multiple MPV_EVENT_HOOK for the
  /// same hook). If this can happen for a specific hook type, it will be
  /// explicitly documented in the manpage.
  ///
  /// Only the mpv_handle on which this was called will receive the hook events,
  /// or can "continue" them.
  ///
  /// @param [replyUserdata] This will be used for the mpv_event.reply_userdata
  ///                       field for the received MPV_EVENT_HOOK events.
  ///                       If you have no use for this, pass 0.
  /// @param [name] The hook name. This should be one of the documented names. But
  ///             if the name is unknown, the hook event will simply be never
  ///             raised.
  /// @param [priority] See remarks above. Use 0 as a neutral default.
  void hookAdd(int replyUserdata, String name, int priority) {
    _handleErrorCode(_bindings.mpv_hook_add(
        handle, replyUserdata, name.toNativeChar(), priority));
  }

  /// Respond to a MPV_EVENT_HOOK event. You must call this after you have handled
  /// the event. There is no way to "cancel" or "stop" the hook.
  ///
  /// Calling this will will typically unblock the player for whatever the hook
  /// is responsible for (e.g. for the "on_load" hook it lets it continue
  /// playback).
  ///
  /// It is explicitly undefined behavior to call this more than once for each
  /// MPV_EVENT_HOOK, to pass an incorrect ID, or to call this on a mpv_handle
  /// different from the one that registered the handler and received the event.
  ///
  /// @param [id] This must be the value of the mpv_event_hook.id field for the
  ///           corresponding MPV_EVENT_HOOK.
  void hookContinue(int id) {
    _handleErrorCode(_bindings.mpv_hook_continue(handle, id));
  }

  /// when the events are received.
  void _onEvents() {
    while (_mpvClientMap.containsKey(_key.value)) {
      final event = waitEvent(0);
      if (event.ref.event_id == mpv_event_id.MPV_EVENT_NONE) {
        break;
      }
      _handleEvent(event);
    }
  }

  /// Handle mpv events.
  void _handleEvent(Pointer<mpv_event> event) {
    final eventId = event.ref.event_id;
    if (_eventListeners.containsKey(eventId)) {
      for (final listener in _eventListeners[eventId]!) {
        listener.call(event);
      }
    }
  }
}
