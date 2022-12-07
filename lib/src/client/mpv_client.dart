part of mpv_bindings;

/// Mpv client API.
class MpvClient {
  /// Mpv bindings.
  final MpvBindings _bindings;

  /// Client context used by the client API. Every client has its own private
  /// handle.
  final Pointer<mpv_handle> handle;

  /// Create mpv client.
  MpvClient({
    MpvBindings? bindings,
  })  : _bindings = bindings ?? MpvLib.bindings,
        handle = (bindings ?? MpvLib.bindings).mpv_create();

  /// Create mpv client with handle.
  MpvClient.handle({
    MpvBindings? bindings,
    required this.handle,
  }) : _bindings = bindings ?? MpvLib.bindings;

  /// Return the MPV_CLIENT_API_VERSION the mpv source has been compiled with.
  int get apiVersion {
    return _bindings.mpv_client_api_version();
  }

  /// Return a string describing the error. For unknown errors, the string
  /// "unknown error" is returned.
  ///
  /// [error] error number, see enum mpv_error
  /// return A static string describing the error. The string is completely
  /// static, i.e. doesn't need to be deallocated, and is valid forever.
  String errorString(int error) {
    return _bindings.mpv_error_string(error).toDartString();
  }

  /// General function to deallocate memory returned by some of the API functions.
  /// Call this only if it's explicitly documented as allowed. Calling this on
  /// mpv memory not owned by the caller will lead to undefined behavior.
  ///
  /// [data] A valid pointer returned by the API, or NULL.
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
  ///
  /// return error code
  int initialize() {
    return _bindings.mpv_initialize(handle);
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
  /// [name] The client name. This will be returned by mpv_client_name(). If
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
  /// [filename] absolute path to the config file on the local filesystem
  /// return error code
  int loadConfigFile(String filename) {
    return _bindings.mpv_load_config_file(handle, filename.toNativeChar());
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
}
