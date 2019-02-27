#import "MSServiceAbstract.h"
#import "MSDocument.h"
#import "MSDocuments.h"
#import "MSSerializableDocument.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * App Data Storage service.
 */

@class MSDocument;
@class MSDocuments;

// Default partitions

// User partition
// An authenticated user can read/write documents in this partition
static NSString *const MSDataSourceUserPartition =  @"user-%@";

// Readonly partition
// Everyone can read documents in this partition
// Writes is not allowed via the SDK
static NSString *const MSDataSourceReadOnlyPartition = @"readonly";

@interface MSDataStorage<T : id<MSSerializableDocument>> : MSServiceAbstract



typedef void (^MSDownloadDocumentCompletionHandler)(MSDocument<T>* document);
typedef void (^MSDownloadDocumentsCompletionHandler)(MSDocuments<T>* documents);


// Read a document
// The document type (T) must be JSON deserializable
+ (void)readWithPartition:(NSString *)partition documentId:(NSString *)documentId documentType:(Class)documentType completionHandler:(MSDownloadDocumentCompletionHandler)completionHandler;

// List (need optional signature to configure page size)
// The document type (T) must be JSON deserializable
+ (void)readWithPartition:(NSString *)partition documentType:(Class)documentType completionHandler: (MSDownloadDocumentsCompletionHandler)completionHandler;

// Create a document
// The document instance (T) must be JSON serializable
+ (void)createWithPartition:(NSString *)partition documentId:(NSString *)documentId document:(T)document completionHandler:(MSDownloadDocumentCompletionHandler)completionHandler;

// Replace a document
// The document instance (T) must be JSON serializable
+ (void)replaceWithPartition:(NSString *)partition documentId:(NSString *)documentId document:(T)document completionHandler:(MSDownloadDocumentCompletionHandler)completionHandler;

// Delete a document
+ (void)deleteDocumentWithPartition:(NSString *)partition documentId:(NSString *)documentId completionHandler:(void (^)(MSDataSourceError* error))completionHandler;

@end
NS_ASSUME_NONNULL_END
