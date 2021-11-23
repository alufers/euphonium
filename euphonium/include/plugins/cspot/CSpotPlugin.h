#ifndef EUPHONIUM_CSPOT_PLUGIN_H
#define EUPHONIUM_CSPOT_PLUGIN_H

#include "ScriptLoader.h"
#include <sol.hpp>
#include "ConfigJSON.h"
#include "MercuryManager.h"
#include "EuphoniumLog.h"
#include "Logger.h"
#include "Task.h"
#include "ZeroconfAuthenticator.h"
#include "Session.h"
#include "CoreEvents.h"
#include "SpircController.h"
#include "FakeAudioSink.h"
#include "CliFile.h"
#include "plugins/http/HTTPModule.h"
#include "Module.h"
#include "BellUtils.h"
#include <atomic>
#include <mutex>

class CSpotPlugin : public Module, public bell::Task
{
private:
    std::shared_ptr<MercuryManager> mercuryManager;
    std::shared_ptr<SpircController> spircController;
    std::shared_ptr<FakeAudioSink> fakeAudioSink;
    std::atomic<bool> isRunning = false;
    std::mutex runningMutex;
    authCallback createPlayerCallback;
    std::shared_ptr<LoginBlob> authBlob;
    std::shared_ptr<ZeroconfAuthenticator> authenticator = nullptr;
    void mapConfig();

public:
    CSpotPlugin();
    void loadScript(std::shared_ptr<ScriptLoader> scriptLoader);
    void setupLuaBindings();
    void configurationUpdated();
    void shutdown();
    void startAudioThread();
    void runTask();
};

#endif