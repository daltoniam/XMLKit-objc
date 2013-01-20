//
//  XMLKit.h
//  kqueue
//
//  Created by Dalton Cherry on 9/4/12.
//  Copyright (c) 2012 Lightspeed Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
//////////////////////////////////////////////////////////////////////////////////////
@interface XMLElement : NSObject

@property(nonatomic,retain)NSMutableArray* childern;
@property(nonatomic,retain)NSMutableDictionary* attributes;
@property(nonatomic, copy)NSString* name;
@property(nonatomic, copy)NSString* text;
@property(nonatomic, retain)XMLElement* parent;
//@property(nonatomic, assign)BOOL isValid;

-(NSString*)convertToString;
-(XMLElement*)findElement:(NSString*)tag;
-(NSArray*)findElements:(NSString*)tag;

+(XMLElement*)elementWithName:(NSString*)name attributes:(NSDictionary*)dict;

@end
//////////////////////////////////////////////////////////////////////////////////////
@interface XMLKit : NSObject
{
    XMLElement* rootElement;
    XMLElement* currentElement;
    BOOL isValid;
}

+(XMLElement*)ParseXMLString:(NSString*)string;

-(XMLElement*)parse:(NSString*)xmlString;

@end
//////////////////////////////////////////////////////////////////////////////////////
@interface NSString (XMLKit)

-(XMLElement*)XMLObjectFromString;
-(NSString*)stripXMLTags;
-(NSString*)xmlSafe;

@end
//////////////////////////////////////////////////////////////////////////////////////
