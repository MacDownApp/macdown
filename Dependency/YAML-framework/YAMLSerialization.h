//
//  YAMLSerialization.h
//  YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//	Released under MIT License
//
//  Copyright 2010 Mirek Rusin
//	Copyright 2010 Stanislav Yudin
//

#import <Foundation/Foundation.h>
#import "yaml.h"

// Mimics NSPropertyListMutabilityOptions
typedef enum {
    kYAMLReadOptionImmutable                  = 0x0000000000000001,
    kYAMLReadOptionMutableContainers          = 0x0000000000000010,
    kYAMLReadOptionMutableContainersAndLeaves = 0x0000000000000110,
    kYAMLReadOptionStringScalars              = 0x0000000000001000
} YAMLReadOptions;

typedef enum {
    kYAMLErrorNoErrors,
    kYAMLErrorCodeParserInitializationFailed,
    kYAMLErrorCodeParseError,
    kYAMLErrorCodeEmitterError,
    kYAMLErrorInvalidOptions,
    kYAMLErrorCodeOutOfMemory,
    kYAMLErrorInvalidYamlObject,
} YAMLErrorCode;

typedef enum {
    kYAMLWriteOptionSingleDocument    = 0x0000000000000001,
    kYAMLWriteOptionMultipleDocuments = 0x0000000000000010,
} YAMLWriteOptions;

extern NSString *const YAMLErrorDomain;

@interface YAMLSerialization : NSObject

#pragma mark YAML reading

// Returns all document objects from parsed YAML stream.
+ (NSMutableArray *) objectsWithYAMLStream: (NSInputStream *) stream
                                   options: (YAMLReadOptions) opt
                                     error: (NSError **) error;

// Returns all document objects from parsed YAML data.
+ (NSMutableArray *) objectsWithYAMLData: (NSData *) data
                                 options: (YAMLReadOptions) opt
                                   error: (NSError **) error;

// Returns all document objects from parsed YAML string.
+ (NSMutableArray *) objectsWithYAMLString: (NSString *) string
                                   options: (YAMLReadOptions) opt
                                     error: (NSError **) error;

// Returns first object from parsed YAML stream.
+ (id) objectWithYAMLStream: (NSInputStream *) stream
                    options: (YAMLReadOptions) opt
                      error: (NSError **) error;

// Returns first object from parsed YAML data.
+ (id) objectWithYAMLData: (NSData *) data
                  options: (YAMLReadOptions) opt
                    error: (NSError **) error;

// Returns first object from parsed YAML string.
+ (id) objectWithYAMLString: (NSString *) string
                    options: (YAMLReadOptions) opt
                      error: (NSError **) error;

#pragma mark Writing YAML

// Returns YES on success, NO otherwise.
+ (BOOL) writeObject: (id) object
        toYAMLStream: (NSOutputStream *) stream
             options: (YAMLWriteOptions) opt
               error: (NSError **) error;

// Caller is responsible for releasing returned object.
+ (NSData *) createYAMLDataWithObject: (id) object
                              options: (YAMLWriteOptions) opt
                                error: (NSError **) error NS_RETURNS_RETAINED;

// Returns autoreleased object.
+ (NSData *) YAMLDataWithObject: (id) object
                        options: (YAMLWriteOptions) opt
                          error: (NSError **) error;

// Caller is responsible for releasing returned object.
+ (NSString *) createYAMLStringWithObject: (id) object
                                  options: (YAMLWriteOptions) opt
                                    error: (NSError **) error NS_RETURNS_RETAINED;

// Returns autoreleased object.
+ (NSString *) YAMLStringWithObject: (id) object
                            options: (YAMLWriteOptions) opt
                              error: (NSError **) error;

#pragma mark Deprecated

// Deprecated, use objectsWithYAMLStream:options:error or objectWithYAMLStream:options:error instead.
+ (NSMutableArray *) YAMLWithStream: (NSInputStream *) stream options: (YAMLReadOptions) opt error: (NSError **) error __attribute__((deprecated));

// Deprecated, use objectsWithYAMLData:options:error or objectWithYAMLData:options:error instead.
+ (NSMutableArray *) YAMLWithData: (NSData *) data options: (YAMLReadOptions) opt error: (NSError **) error __attribute__((deprecated));

// Deprecated, use YAMLDataWithObject:options:error or createYAMLDataWithObject:options:error instead.
+ (NSData *) dataFromYAML: (id) object options: (YAMLWriteOptions) opt error: (NSError **) error __attribute__((deprecated));

// Deprecated, use writeYAMLObject:toStream:options:error instead.
+ (BOOL) writeYAML: (id) object toStream: (NSOutputStream *) stream options: (YAMLWriteOptions) opt error: (NSError **) error __attribute__((deprecated));

@end
