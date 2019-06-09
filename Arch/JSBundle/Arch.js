var global = this;

// 维护待执行的 JS 消息队列，以及 JS 直接调用 Native 的方法
// BatchedBridge 对象会被注入到 global.__batchedBridge 中
var BatchedBridge = (function() {
    const MODULE_INDEX = 0;
    const METHOD_INDEX = 1;
    const PARAMS = 2;
    const MIN_TIME_BETWEEN_FLUSHES_MS = 5;

    // Native 直接调用 JS 的方法，没有返回值
    // 由 Native 拿到 global 对象直接调用
    // 每次 Native 调用 JS 时，会顺带将消息队列中未执行的 JS->Native 返回给 Native 执行
    var callFunctionReturnFlushedQueue = function(module, method, args) {
        this.__callFunction(module, method, args);
        return this.flushedQueue();
    }

    // OC 直接调用 JS 的方法，有返回值
    // 由 Native 拿到 global 对象直接调用
    // 每次 Native 调用 JS 时，会顺带将消息队列中未执行的 JS->Native 返回给 Native 执行
    var callFunctionReturnResultAndFlushedQueue = function(module, method, args) {
        const result = this.__callFunction(module, method, args);
        return [result, this.flushedQueue()];
    }

    // OC 执行 JS 的 Callback，顺带返回未处理的 JS->Native 消息
    // 由 Native 拿到 global 对象直接调用
    var invokeCallbackAndReturnFlushedQueue = function(callbackId, args) {
        this.__invokeCallback(callbackId, args);
        return this.flushedQueue();
    }

    // 返回未处理的 Native 调用，并清理消息队列
    var flushedQueue = function() {
        const queue = this.queue;
        this.queue = [[], [], [], this.callID];
        return queue[0].length ? queue: null;
    }

    var __callFunction = function(module, method, args) {
        // 记录消息队列清理时间
        this._lastFlush = new Date().getTime();
        const moduleMethods = this.callableModules[module];
        // 执行 JS 调用
        const result = moduleMethods[method].apply(null, args);
        return args;
    }

    var __invokeCallback = function(cbID, args) {
        // 记录消息队列清理时间
        this._lastFlush = new Date().getTime();
        const callback = this.callbacks[cbID];
        if (!callback) {
        return;
        }
        this.callbacks[cbID] = null;
        callback.apply(null, args);
    }

    // 所有 JS 需要调用 OC 时都会走这个方法，在 NativeModules.js 中使用。
    var enqueueNativeCall = function(moduleID, methodID, params, onFail, onSuccess) {
        if (onFail || onSuccess) {
            // 如果存在 callback 回调，添加到 callbacks 字典中
            // OC 根据 callbackID 来执行回调
            if (onFail) {
                params.push(this.callbackID);
                this.callbacks[this.callbackID++] = onFail;
            }
            if (onSuccess) {
                params.push(this.callbackID);
                this.callbacks[this.callbackID++] = onSuccess;
            }
        }
        // 将 Native 调用存入消息队列中
        this.queue[MODULE_INDEX].push(moduleID);
        this.queue[METHOD_INDEX].push(methodID);
        this.queue[PARAMS].push(params);

        // 每次都有 ID，没啥用
        this.callID++;

        const now = new Date().getTime();
        // 检测原生端是否为 global 添加过 nativeFlushQueueImmediate 方法
        // 如果有这个方法，并且 5ms 内队列还有未处理的调用，就主动调用 nativeFlushQueueImmediate 触发 Native 调用
        if (global.nativeFlushQueueImmediate && now - this.lastFlush > MIN_TIME_BETWEEN_FLUSHES_MS) {
            global.nativeFlushQueueImmediate(this.queue);
            // 调用后清空队列
            this.queue = [[], [], [], this.callID];
        }
    }

  // 注册暴露给 OC 的 JS 模块
    var registerJSModule = function(name, module) {
        this.callableModules[name] = module;
    }
  
    return {
        callID: 0,
        queue: [[], [], [], 0],
        callbacks: [],
        callbackID: 0,
        lastFlush: 0,
        // 支持 Native 调用的 JS modules
        callableModules: {},
        
        callFunctionReturnFlushedQueue: callFunctionReturnFlushedQueue,
        callFunctionReturnResultAndFlushedQueue: callFunctionReturnResultAndFlushedQueue,
        invokeCallbackAndReturnFlushedQueue: invokeCallbackAndReturnFlushedQueue,
        flushedQueue: flushedQueue,
        __callFunction: __callFunction,
        __invokeCallback: __invokeCallback,
        enqueueNativeCall: enqueueNativeCall,
    };
})();

// Native 暴露给 JS 的模块信息
var NativeModules = function() {
    
    // 构造 Native 对应的 JS Module
    function getModule(config, moduleID) {
        var [ moduleName, constants, methods, promiseMethods, syncMethods ] = config;
        if (!constants && !methods) {
            return { name: moduleName };
        }
        var module = {};
        methods && methods.forEach(function(methodName, methodID) {
           var isPromise = promiseMethods;
           var isSync = syncMethods;
           var methodType = isPromise ? 'promise' : (isSync ? 'sync' : 'async');
           module[methodName] = getMethod(moduleID, methodID, methodType);
        });

        return { name: moduleName, module: module };
    }
    
    // 构造与 Native 对应的 JS Method
    function getMethod(moduleID, methodID, type) {
        var fn = null;
        if (type === 'promise') {
        } else if (type === 'sync') {
        } else {
            // 这里只处理了异步调用的方法
            // fn 的参数为 module method params failCallback successCallback
            // fn 闭包捕获了 moduleID, methodID
            // callback 为可选参数
            fn = function(...args) {
                const lastArg = args.length > 0 ? args[args.length - 1] : null;
                const secondLastArg = args.length > 1 ? args[args.length - 2] : null;
                
                const hasErrorCallback = typeof lastArg === 'function';
                const hasSuccessCallback = typeof secondLastArg === 'function';
                
                const onSuccess = hasSuccessCallback ? lastArg : null;
                const onFail = hasErrorCallback ? secondLastArg : null;
                
                const callbackCount = hasSuccessCallback + hasErrorCallback;
                args = args.slice(0, args.length - callbackCount);
                
                // 触发 Native 调用
                BatchedBridge.enqueueNativeCall(moduleID, methodID, args, onFail, onSuccess);
            }
        }
        // 通过 fn 闭包持有 moduleID 和 methodID
        // 根据 methodName 取
        fn.type = type;
        return fn;
    }

    var modules = {}
    
    // 取出 Native 暴露给 JS 的模块
    // 该属性在 AHJSExecutor.m 文件注入的
    var bridgeConfig = global.__batchedBridgeConfig;
    // 遍历每个模块，生成 JS 端调用信息
    (bridgeConfig.remoteModuleConfig || []).forEach(function(config, moduleID) {
        var info = getModule(config, moduleID);
        if (!info) {
            return;
        }
        if (info.module) {
            // 原生 module 存入 NativeModules，提供 JS 调用
            modules[info.name] = info.module;
        }
    });
    
    return modules;
}();

// 将 BatchedBridge 注入 global.__batchedBridge
Object.defineProperty(global, '__batchedBridge', {
  configurable: true,
  value: BatchedBridge,
});

//////////////////////////////////// DEMO ///////////////////////////////////////////

var person = NativeModules.Person;
person.run(); // AHPerson.m 中 run 方法将会被调用

