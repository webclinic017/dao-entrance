import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:asyou_app/application/store/im_state.dart';
import 'package:asyou_app/native_wraper.io.dart';
import 'package:asyou_app/router.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart' show AuthenticationUserIdentifier, Client, HiveCollectionsDatabase, LoginType;
import 'package:path_provider/path_provider.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:asyou_app/application/service/apis/system_api.dart';
import 'package:asyou_app/infra/components/loading_dialog.dart';
import 'package:asyou_app/domain/models/models.dart';
import 'package:asyou_app/domain/utils/functions.dart';
import 'package:asyou_app/domain/utils/platform_infos.dart';
import 'package:asyou_app/domain/utils/screen/screen.dart';

part 'app.freezed.dart';

@freezed
class AppState with _$AppState {
  const factory AppState({
    @Default("") String signCtx,
    @Default("") String sign,
    Account? me,
    @Default({}) Map<String, Client> connections,
    @Default({}) Map<String, ImState> connectionStates,
    @Default("") String currentOrg,
    @Default(0) int lastSyncTime,
  }) = _AppState;
}

class AppCubit extends Cubit<AppState> {
  AppCubit({state = const AppState()}) : super(state);

  // 当前账户
  String get currentId => state.currentOrg;

  String get signCtx => state.signCtx;

  String get sign => state.sign;

  // 当前账户
  Account? get me => state.me;

  // 多连接
  Map<String, Client> get connections => state.connections;

  // 连接状态
  Map<String, ImState> get connectionStates => state.connectionStates;

  loginWithCache(Account user) {
    emit(state.copyWith(
      me: user,
      signCtx: "",
      sign: "",
    ));
  }

  // 登陆账户
  login(Account user) async {
    final ctx = globalCtx();
    final signCtx = "${"{\"t\":\"${DateTime.now().millisecondsSinceEpoch}"}\"}";
    String sign = "";
    if (!PlatformInfos.isWeb) {
      final input = await showTextInputDialog(
        useRootNavigator: false,
        context: ctx,
        title: L10n.of(ctx)!.password,
        okLabel: L10n.of(ctx)!.ok,
        cancelLabel: L10n.of(ctx)!.cancel,
        textFields: [
          DialogTextField(
            obscureText: true,
            hintText: L10n.of(ctx)!.pleaseEnterYourPassword,
            initialText: "",
          )
        ],
      );
      if (input == null) return false;
      final res = await waitFutureLoading<String>(
        context: globalCtx(),
        future: () async {
          final pwd = input[0];
          try {
            await rustApi.addKeyring(keyringStr: user.chainData, password: pwd);
            sign = await rustApi.signFromAddress(
              address: user.address,
              ctx: signCtx,
            );
          } catch (e) {
            return "密码错误";
          }

          emit(state.copyWith(
            me: user,
            signCtx: signCtx,
            sign: sign,
          ));
          return "ok";
        },
      );
      if (res.result == "ok") {
        final systemStore = await SystemApi.create();
        systemStore.saveLogin(user.address);
        return true;
      }
      BotToast.showText(
        text: res.result ?? "未知错误",
        duration: const Duration(seconds: 2),
      );
    } else {
      await rustApi.addKeyring(keyringStr: user.chainData, password: "");
      sign = await rustApi.signFromAddress(
        address: user.address,
        ctx: signCtx,
      );
      emit(state.copyWith(
        me: user,
        signCtx: signCtx,
        sign: sign,
      ));
      final systemStore = await SystemApi.create();
      systemStore.saveLogin(user.address);
      return true;
    }
    return false;
  }

  // 登出账户
  logout() async {
    connections.forEach((key, value) async {
      await value.logout();
      await value.dispose();
    });
    connectionStates.forEach((key, value) async {
      await value.dispose();
    });
    const storage = FlutterSecureStorage();
    await storage.delete(key: "login_state");
    emit(const AppState());
    globalCtx().router.back();
  }

  // 连接账户
  Future<bool> connect(AccountOrg org) async {
    // 构建账户密码
    final userName = '${me!.address}@${org.domain}/${platformGet()}';

    printInfo("connect => $userName");

    // 已有的连接
    if (connections[userName] != null) {
      final client = connections[userName]!;
      if (!client.isLogged()) {
        try {
          await client.login(
            LoginType.mLoginPassword,
            identifier: AuthenticationUserIdentifier(user: me!.address),
            password: "$signCtx||$sign",
          );
        } catch (e) {
          printDebug("注册出现错误 => $e");
        }
      }

      if (!client.isLogged()) {
        throw "连接错误";
      }
      return true;
    }

    final client = Client(
      userName,
      databaseBuilder: (_) async {
        if (PlatformInfos.isWeb) {
          final db = HiveCollectionsDatabase(
            org.domain!.replaceAll(".", "_"),
            me!.address,
          );
          await db.open();
          return db;
        }
        final dir = await getApplicationSupportDirectory();
        printDebug("hlive ===> ${dir.path} ${org.domain!.replaceAll(".", "_")}");
        final db = HiveCollectionsDatabase(
          org.domain!.replaceAll(".", "_"),
          "${dir.path}/${me!.address}",
        );
        await db.open();
        return db;
      },
    );

    // 链接节点
    await client.init();
    await client.checkHomeserver(Uri.http(org.domain!, ''));

    if (!client.isLogged()) {
      try {
        await client.uiaRequestBackground((auth) {
          return client.register(
            username: me!.address,
            password: "$signCtx||$sign",
            initialDeviceDisplayName: platformGet(),
            auth: auth,
          );
        });
      } catch (e) {
        printDebug("注册出现错误 => $e");
      }
    }

    // 重新验证
    if (!client.isLogged()) {
      try {
        await client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: me!.address),
          password: "$signCtx||$sign",
        );
      } catch (e) {
        printError("登陆出现错误 => $e");
      }
    }

    if (!client.isLogged()) {
      throw "连接错误";
    }

    if (client.userID != null) {
      var displayName = await client.getDisplayName(client.userID!) ?? "";
      if (getUserShortId(displayName) == getUserShortId(client.userID!)) {
        await client.setDisplayName(client.userID!, me!.name);
      }
    }

    emit(state.copyWith(
      connections: {
        ...connections,
        userName: client,
      },
      connectionStates: {
        ...connectionStates,
        userName: ImState(userName, client, org, me!),
      },
    ));
    return true;
  }

  // 设置当前账户
  setCurrent(AccountOrg org) {
    final id = '${me!.address}@${org.domain}/${platformGet()}';
    emit(state.copyWith(currentOrg: id));
    state.connectionStates[id]?.syncChannel();
  }

  // 获取当前连接
  Client? get current => connections[currentId];

  // 获取当前连接
  ImState? get currentState => connectionStates[currentId];

  @Deprecated('remove')
  stateChange() {
    emit(state.copyWith());
  }

  // 设置当前账户
  setChannels() {
    // 没有当前频道情况下
    emit(state.copyWith(lastSyncTime: DateTime.now().millisecondsSinceEpoch));
  }
}
