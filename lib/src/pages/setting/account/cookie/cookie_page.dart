import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../exception/eh_site_exception.dart';
import '../../../../network/eh_ip_provider.dart';
import '../../../../network/eh_timeout_translator.dart';
import '../../../../service/log.dart';
import '../../../../setting/network_setting.dart';

class CookiePage extends StatefulWidget {
  const CookiePage({super.key});

  @override
  State<CookiePage> createState() => _CookiePageState();
}

class _CookiePageState extends State<CookiePage> {
  Dio? _dio;
  LoadingState _refreshIgneousState = LoadingState.idle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('accountSetting'.tr),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyCookies),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: ehRequest.cookies
            .map(
              (cookie) => ListTile(
                title: Text(cookie.name),
                subtitle: Text(cookie.value),
                trailing: cookie.name == EHConsts.igneousCookieName
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LoadingStateIndicator(
                            loadingState: _refreshIgneousState,
                            loadingWidgetBuilder: () => const CupertinoActivityIndicator().marginOnly(right: 10),
                            idleWidgetBuilder: () => IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshIgneousCookie),
                            successWidgetSameWithIdle: true,
                            errorWidgetSameWithIdle: true,
                          )
                        ],
                      )
                    : null,
                onTap: _copyAllCookies,
                dense: true,
              ),
            )
            .toList(),
      ).withListTileTheme(context),
    );
  }

  Future<void> _copyAllCookies() async {
    await FlutterClipboard.copy(CookieUtil.parse2String(ehRequest.cookies));
    toast('hasCopiedToClipboard'.tr);
  }

  Future<void> _copyCookies() async {
    await FlutterClipboard.copy(
      CookieUtil.parse2String(
        ehRequest.cookies
            .where(
              (cookie) => cookie.name == 'ipb_member_id' || cookie.name == 'ipb_pass_hash' || cookie.name == 'igneous',
            )
            .toList(),
      ),
    );
    toast('hasCopiedToClipboard'.tr);
  }

  Future<void> _refreshIgneousCookie() async {
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    await _initDio();

    if (_refreshIgneousState == LoadingState.loading) {
      return;
    }

    setStateSafely(() {
      _refreshIgneousState = LoadingState.loading;
    });

    try {
      Response response = await _dio!.request(
        EHConsts.EXIndex,
        options: Options(headers: {
          'cookie': CookieUtil.parse2String(
            [
              Cookie('ipb_member_id', userSetting.ipbMemberId.value.toString()),
              Cookie('ipb_pass_hash', userSetting.ipbPassHash.value!),
            ],
          )
        }),
      );

      log.info('Refresh igneous cookie, set-cookie: ${response.headers.value('set-cookie')}');

      List<String>? cookiePairs = response.headers.value('set-cookie')?.split(';');
      if (cookiePairs == null) {
        snack('refreshIgneousFailed'.tr, 'Sad panda');
        setStateSafely(() {
          _refreshIgneousState = LoadingState.error;
        });
        return;
      }

      for (String cookiePair in cookiePairs) {
        String name = cookiePair.split('=')[0];
        String value = cookiePair.split('=')[1];
        if (name != EHConsts.igneousCookieName) {
          continue;
        }

        if (value == 'mystery') {
          snack('refreshIgneousFailed'.tr, 'Sad panda');
          setStateSafely(() {
            _refreshIgneousState = LoadingState.error;
          });
          return;
        }

        ehRequest.storeEHCookies([Cookie(name, value)]);
        toast('success'.tr);
        setStateSafely(() {
          _refreshIgneousState = LoadingState.success;
        });
        return;
      }

      snack('refreshIgneousFailed'.tr, 'Sad panda');
      setStateSafely(() {
        _refreshIgneousState = LoadingState.error;
      });
      return;
    } on DioException catch (e) {
      log.error('Refresh igneous failed: ${e.message}');
      snack('refreshIgneousFailed'.tr, e.errorMsg ?? '');
      setStateSafely(() {
        _refreshIgneousState = LoadingState.error;
      });
      return;
    } on EHSiteException catch (e) {
      log.error('Refresh igneous failed: ${e.message}');
      snack('refreshIgneousFailed'.tr, e.message);
      setStateSafely(() {
        _refreshIgneousState = LoadingState.error;
      });
      return;
    } catch (e, s) {
      log.error('Refresh igneous failed: $e');
      snack('refreshIgneousFailed'.tr, e.toString());
      setStateSafely(() {
        _refreshIgneousState = LoadingState.error;
      });
      return;
    }
  }

  Future<void> _initDio() async {
    if (_dio != null) {
      return;
    }

    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    EHIpProvider _ehIpProvider = RoundRobinIpProvider(NetworkSetting.host2IPs);

    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (networkSetting.enableDomainFronting.isFalse) {
          handler.next(options);
          return;
        }

        String rawPath = options.path;
        String host = options.uri.host;
        if (!_ehIpProvider.supports(host)) {
          handler.next(options);
          return;
        }

        String ip = _ehIpProvider.nextIP(host);
        handler.next(options.copyWith(
          path: rawPath.replaceFirst(host, ip),
          headers: {...options.headers, 'host': host},
          extra: options.extra..[EHRequest.domainFrontingExtraKey] = {'host': host, 'ip': ip},
        ));
      },
      onError: (DioException e, ErrorInterceptorHandler handler) {
        if (!e.requestOptions.extra.containsKey(EHRequest.domainFrontingExtraKey)) {
          handler.next(e);
          return;
        }

        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.badResponse || e.type == DioExceptionType.connectionError) {
          String host = e.requestOptions.extra[EHRequest.domainFrontingExtraKey]['host'];
          String ip = e.requestOptions.extra[EHRequest.domainFrontingExtraKey]['ip'];
          _ehIpProvider.addUnavailableIp(host, ip);
          log.info('Refresh igneous, add unavailable host-ip: $host-$ip');
        }

        handler.next(e);
      },
    ));

    _dio!.interceptors.add(EHTimeoutTranslator());
  }
}
