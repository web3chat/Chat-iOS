// 谈信（Tanxin）内置钱包 EIP-1193 Provider（与 WebViewController iosHost 配对）
(function () {
    if (window.__tanxinWalletInjected) {
        return;
    }
    window.__tanxinWalletInjected = true;

    const _callbacks = new Map();
    /** 与原生回包 id 统一为字符串键，避免 number/string 不一致导致 Map 取不到、Promise 永久 pending */
    function normalizeRequestId(id) {
        if (id === null || id === undefined) {
            return '';
        }
        return String(id);
    }
    /** 单调递增，与 randomUUID 组合，避免并发请求 requestId 碰撞导致 Map 覆盖、前序 Promise 永不结束 */
    var __requestIdSeq = 0;
    function generateRequestId() {
        if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
            return crypto.randomUUID();
        }
        __requestIdSeq += 1;
        return 'w' + Date.now().toString(36) + '-' + __requestIdSeq + '-' + Math.random().toString(36).slice(2, 12);
    }
    const _listeners = { chainChanged: [], accountsChanged: [], connect: [], disconnect: [] };

    /** 尽快在微任务/下一 macrotask 执行；勿用 requestAnimationFrame 兑现 Promise（WKWebView 在后台/重绘节流时 rAF 会长时间不触发，导致 Pancake 等 DApp 一直连不上） */
    function runSoon(fn) {
        if (typeof queueMicrotask === 'function') {
            queueMicrotask(fn);
        } else {
            setTimeout(fn, 0);
        }
    }

    const EIP6963_INFO = Object.freeze({
        uuid: 'f2c8b1e4-9d3a-4f7c-a6e2-5b0c1d4e7f9a',
        name: 'Tanxin Wallet',
        icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><circle cx="16" cy="16" r="16" fill="%23666"/></svg>',
        rdns: 'com.tanxin.wallet'
    });

    function announceEip6963() {
        if (!window.ethereum) {
            return;
        }
        try {
            window.dispatchEvent(
                new CustomEvent('eip6963:announceProvider', {
                    detail: Object.freeze({ info: EIP6963_INFO, provider: window.ethereum })
                })
            );
        } catch (e) {}
    }

    /** EIP-1193：用带 code 的 Error reject，减少 wagmi/ethers 里 Uncaught (in promise) */
    function toProviderRpcError(raw) {
        if (raw instanceof Error && typeof raw.code === 'number') {
            return raw;
        }
        if (raw instanceof Error) {
            raw.code = typeof raw.code === 'number' ? raw.code : 4001;
            return raw;
        }
        var o = raw !== null && raw !== undefined && typeof raw === 'object' ? raw : {};
        var code =
            typeof o.code === 'number'
                ? o.code
                : typeof o.code === 'string' && o.code !== ''
                  ? parseInt(o.code, 10) || 4001
                  : 4001;
        var msg =
            o.message != null && String(o.message).length
                ? String(o.message)
                : typeof raw === 'string'
                  ? raw
                  : 'Wallet request rejected';
        var err = new Error(msg);
        err.code = code;
        if (o.data !== undefined) {
            err.data = o.data;
        }
        return err;
    }

    const provider = {
        isMetaMask: true,
        selectedAddress: null,
        chainId: null,
        networkVersion: null,
        providers: null,

        on: function (event, cb) {
            if (!_listeners[event]) {
                _listeners[event] = [];
            }
            _listeners[event].push(cb);
            return provider;
        },
        removeListener: function (event, cb) {
            const arr = _listeners[event];
            if (!arr) {
                return;
            }
            const i = arr.indexOf(cb);
            if (i >= 0) {
                arr.splice(i, 1);
            }
        },
        emit: function (event) {
            const args = [].slice.call(arguments, 1);
            (_listeners[event] || []).forEach(function (cb) {
                try {
                    cb.apply(null, args);
                } catch (e) {}
            });
        },

        enable: function () {
            return provider.request({ method: 'eth_requestAccounts' });
        },

        isConnected: function () {
            return Promise.resolve(!!(provider.selectedAddress && provider.selectedAddress.length));
        },

        request: async function (args) {
            const method = args && args.method;
            const params = (args && args.params) || [];
            /** 与 WebViewController routeMetaMaskIosHostRequest / WebViewMetaMaskCoordinator 一致 */
            const nativeMethods = [
                'eth_requestAccounts',
                'eth_accounts',
                'eth_chainId',
                'eth_sign',
                'personal_sign',
                'eth_signTypedData',
                'eth_signTypedData_v4',
                'net_version',
                'eth_sendTransaction',
                'eth_sendRawTransaction',
                'wallet_switchEthereumChain',
                'wallet_addEthereumChain',
                'wallet_getPermissions',
                'wallet_requestPermissions',
                'eth_call',
                'eth_estimateGas',
                'web3_clientVersion',
                /* 以下由原生透传至当前链 JSON-RPC（handleGenericRpc） */
                'eth_getBalance',
                'eth_gasPrice',
                'eth_blockNumber',
                'eth_getTransactionCount',
                'eth_getTransactionReceipt',
                'eth_getBlockByNumber',
                'eth_getBlockByHash',
                'eth_getTransactionByHash',
                'eth_getCode',
                'eth_getLogs',
                'eth_getStorageAt',
                'eth_getBlockTransactionCountByHash',
                'eth_getBlockTransactionCountByNumber',
                'eth_getUncleByBlockHashAndIndex',
                'eth_getUncleByBlockNumberAndIndex',
                'eth_protocolVersion',
                'eth_syncing',
                'eth_feeHistory',
                'eth_maxPriorityFeePerGas',
                'eth_createAccessList',
                'eth_newFilter',
                'eth_newBlockFilter',
                'eth_newPendingTransactionFilter',
                'eth_uninstallFilter',
                'eth_getFilterChanges',
                'eth_getFilterLogs'
            ];

            if (nativeMethods.indexOf(method) >= 0) {
                return new Promise(function (resolve, reject) {
                    var requestId = generateRequestId();
                    if (_callbacks.has(requestId)) {
                        requestId = generateRequestId();
                    }
                    var ridKey = normalizeRequestId(requestId);
                    _callbacks.set(ridKey, { resolve: resolve, reject: reject });

                    const payload = { id: requestId, method: method, params: params };

                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iosHost) {
                        try {
                            window.webkit.messageHandlers.iosHost.postMessage(payload);
                        } catch (e) {
                            _callbacks.delete(ridKey);
                            reject(toProviderRpcError(e));
                        }
                    } else {
                        _callbacks.delete(ridKey);
                        reject(toProviderRpcError({ code: -32603, message: 'iOS WebKit Host not found' }));
                    }
                });
            }
            return Promise.reject(toProviderRpcError({ code: -32601, message: 'Method ' + method + ' not supported' }));
        },

        /** 旧版 web3.js / ethers v4 可能走 sendAsync */
        sendAsync: function (payload, callback) {
            if (!payload || !payload.method) {
                if (callback) {
                    callback({ code: -32602, message: 'Invalid payload' }, null);
                }
                return;
            }
            provider
                .request({ method: payload.method, params: payload.params || [] })
                .then(function (result) {
                    if (callback) {
                        callback(null, { jsonrpc: '2.0', id: payload.id, result: result });
                    }
                })
                .catch(function (err) {
                    if (callback) {
                        callback(
                            typeof err === 'object' && err !== null
                                ? err
                                : { code: -32603, message: String(err) },
                            null
                        );
                    }
                });
        },

        send: function (payload, callback) {
            provider.sendAsync(payload, callback);
        },

        /**
         * 多级重试：下一帧 / macrotask / microtask / 递增延迟，缓解 evaluateJavaScript 与 postMessage 竞态导致的「Promise 丢失」
         * @param retryDepth 0..10
         */
        _onResponse: function (requestId, resultData, errorData, retryDepth) {
            var rid = normalizeRequestId(requestId);
            var depth = typeof retryDepth === 'number' ? retryDepth : 0;
            var callback = _callbacks.get(rid);

            if (!callback) {
                if (depth < 10) {
                    var self = this;
                    var next = function () {
                        self._onResponse(requestId, resultData, errorData, depth + 1);
                    };
                    if (depth === 0) {
                        setTimeout(next, 0);
                    } else if (depth === 1) {
                        setTimeout(next, 0);
                    } else if (typeof queueMicrotask === 'function' && depth === 2) {
                        queueMicrotask(next);
                    } else {
                        setTimeout(next, Math.min(64, 4 * (depth - 1)));
                    }
                } else {
                    console.warn('[wallet] no pending callback for', rid);
                }
                return;
            }

            var cb = callback;
            runSoon(function () {
                try {
                    if (errorData !== null && errorData !== undefined) {
                        cb.reject(toProviderRpcError(errorData));
                    } else {
                        if (
                            Array.isArray(resultData) &&
                            resultData.length > 0 &&
                            resultData[0] &&
                            typeof resultData[0] === 'string' &&
                            resultData[0].indexOf('0x') === 0
                        ) {
                            provider.selectedAddress = resultData[0];
                        }
                        cb.resolve(resultData);
                    }
                } catch (e) {
                    try {
                        cb.reject(toProviderRpcError(e));
                    } catch (e2) {}
                }
                _callbacks.delete(rid);
            });
        },

        _announceEip6963: announceEip6963
    };

    provider.providers = [provider];

    window.ethereum = provider;

    window.addEventListener('eip6963:requestProvider', announceEip6963);

    window.dispatchEvent(new Event('ethereum#initialized'));
    announceEip6963();

    /** 供原生在 didFinishNavigation 调用，确保 SPA 壳子加载后再广播一次 */
    window.__tanxinWalletBridgePing = function () {
        try {
            window.dispatchEvent(new Event('ethereum#initialized'));
            announceEip6963();
        } catch (e) {}
    };

    setTimeout(announceEip6963, 0);
    setTimeout(announceEip6963, 300);
})();
