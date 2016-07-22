#import "AVAAvalanchePrivate.h"
#import "AVAChannelDefault.h"
#import "AVAConstants+Internal.h"
#import "AVAFeaturePrivate.h"
#import "AVAFileStorage.h"
#import "AVAHttpSender.h"
#import "AVALogManagerDefault.h"
#import "AVASettings.h"
#import "AVAUtils.h"
#import "AVADeviceLog.h"
#import "AVAStartSessionLog.h"

static NSString *const kAVAInstallId = @"AVAInstallId";

// Http Headers + Query string
static NSString *const kAVAAppKeyKey = @"App-Key";
static NSString *const kAVAInstallIDKey = @"Install-ID";
static NSString *const kAVAContentType = @"application/json";
static NSString *const kAVAContentTypeKey = @"Content-Type";
static NSString *const kAVAAPIVersion = @"1.0.0-preview20160901";
static NSString *const kAVAAPIVersionKey = @"api-version";

// Base URL
static NSString *const kAVABaseUrl = @"http://avalanche-perf.westus.cloudapp.azure.com:8081";

@implementation AVAAvalanche

+ (id)sharedInstance {
  static AVAAvalanche *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

+ (void)useFeatures:(NSArray<Class> *)features withAppKey:(NSString *)appKey {
  [[self sharedInstance] useFeatures:features withAppKey:appKey];
}
+ (void)setEnabled:(BOOL)isEnabled {
  [[self sharedInstance] setEnabled:isEnabled];
}

#pragma mark - private methods

- (id)init {
  if (self = [super init]) {
    _features = [NSMutableArray new];
  }
  return self;
}
- (void)useFeatures:(NSArray<Class> *)features withAppKey:(NSString *)appKey {

  if (self.featuresStarted) {
    AVALogWarning(@"SDK has already been started. You can call `useFeatures` only once.");
    return;
  }

  // Validate App key
  if ([appKey length] == 0 || ![[NSUUID alloc] initWithUUIDString:appKey]) {
    AVALogError(@"ERROR: AppKey is invalid");
    return;
  }

  // Set app ID and UUID
  self.appKey = appKey;
  self.apiVersion = kAVAAPIVersion;

  // Set install Id
  [self setInstallId];

  [self initializePipeline];

  for (Class obj in features) {
    id<AVAFeaturePrivate> feature = [obj sharedInstance];

    // Set delegate
    feature.delegate = self;
    [self.features addObject:feature];
    [feature startFeature];
  }
  _featuresStarted = YES;
}

- (void)setEnabled:(BOOL)isEnabled {
  
  // Set enable/disable on all features
  for (id<AVAFeaturePrivate> feature in self.features) {
    [feature setEnabled:isEnabled];
  }
  _isEnabled = isEnabled;
}

- (void)initializePipeline {

  // Init device tracker
  _deviceTracker = [[AVADeviceTracker alloc] init];

  // Init session tracker
  _sessionTracker = [[AVASessionTracker alloc] init];
  self.sessionTracker.delegate = self;
  [self.sessionTracker start];

  // Construct http headers
  NSDictionary *headers =
      @{kAVAContentTypeKey : kAVAContentType, kAVAAppKeyKey : _appKey, kAVAInstallIDKey : _installId};

  // Construct the query parameters
  NSDictionary *queryStrings = @{kAVAAPIVersionKey : kAVAAPIVersion};
  AVAHttpSender *sender = [[AVAHttpSender alloc] initWithBaseUrl:kAVABaseUrl headers:headers queryStrings:queryStrings];

  // Construct storage
  AVAFileStorage *storage = [[AVAFileStorage alloc] init];

  // Construct log manager
  _logManager = [[AVALogManagerDefault alloc] initWithSender:sender storage:storage];
}

+ (AVALogLevel)logLevel {
  return AVALogger.currentLogLevel;
}

+ (void)setLogLevel:(AVALogLevel)logLevel {
  AVALogger.currentLogLevel = logLevel;
}

+ (void)setLogHandler:(AVALogHandler)logHandler {
  [AVALogger setLogHandler:logHandler];
}

- (NSString *)appKey {
  return _appKey;
}

- (NSString *)installId {
  return _installId;
}

- (NSString *)apiVersion {
  return _apiVersion;
}

- (void)setInstallId {
  if (_installId)
    return;

  // Check if install id has already been persisted
  NSString *installIdString = [kAVASettings objectForKey:kAVAInstallId];
  self.installId = [kAVASettings objectForKey:kAVAInstallId];

  // Use the persisted install id
  if ([installIdString length] > 0) {
    self.installId = installIdString;
  } else {

    // Create a new random install id
    self.installId = kAVAUUIDString;

    // Persist the install ID string
    [kAVASettings setObject:self.installId forKey:kAVAInstallId];
    [kAVASettings synchronize];
  }
}

#pragma mark - SessionTracker

- (void)feature:(id)feature didCreateLog:(id<AVALog>)log withPriority:(AVAPriority)priority {

  // Set common log info and send log
  [self setCommonLogInfo:log withSessionId:self.sessionTracker.sessionId];
  [self sendLog:log withPriority:AVAPriorityDefault];
}

#pragma mark - AVASessionTrackerDelegate

- (void)sessionTracker:(id)sessionTracker didRenewSessionWithId:(NSString *)sessionId {
  // Refresh device characteristics
  [self.deviceTracker refresh];

  // Create a start session log
  AVAStartSessionLog *log = [[AVAStartSessionLog alloc] init];
  [self setCommonLogInfo:log withSessionId:sessionId];
  
  // Send log
  [self sendLog:log withPriority:AVAPriorityDefault];
}


#pragma mark - private methods

- (void)setCommonLogInfo:(id<AVALog>)log withSessionId:(NSString *)sessionId {
  // Set common log info
  log.sid = sessionId;
  log.toffset = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
  log.device = self.deviceTracker.device;
}

- (void)sendLog:(id<AVALog>)log withPriority:(AVAPriority)priority {
  // Set the last ceated time on the session tracker
  self.sessionTracker.lastCreatedLogTime = [NSDate date];

  // Send log
  [self.logManager processLog:log withPriority:AVAPriorityDefault];
}

@end
