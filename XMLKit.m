//
//  XMLKit.m
//  kqueue
//
//  Created by Dalton Cherry on 9/4/12.
//  Copyright (c) 2012 Lightspeed Systems. All rights reserved.
//

#import "XMLKit.h"
#import <libxml2/libxml/xmlreader.h>

//////////////////////////////////////////////////////////////////////////////////////
@implementation XMLElement

@synthesize childern,attributes,name,text,parent; //isValid
//////////////////////////////////////////////////////////////////////////////////////
+(XMLElement*)elementWithName:(NSString*)name attributes:(NSDictionary*)dict
{
    XMLElement* element = [[[XMLElement alloc] init] autorelease];
    element.name = name;
    element.attributes = [NSMutableDictionary dictionaryWithDictionary:dict];
    element.childern = [NSMutableArray array];
    element.text = @"";
    return element;
}
//////////////////////////////////////////////////////////////////////////////////////
-(NSString*)convertHelper:(XMLElement*)element
{
    NSString* attribs = @"";
    for(id key in element.attributes)
        attribs = [attribs stringByAppendingFormat:@" %@=\"%@\"",key,[element.attributes objectForKey:key]];
    NSString* string = [NSString stringWithFormat:@"<%@%@>%@",element.name,attribs,element.text];
    for(XMLElement* child in element.childern)
        string = [string stringByAppendingString:[self convertHelper:child]];
    string = [string stringByAppendingFormat:@"</%@>",element.name];
    return string;
}
//////////////////////////////////////////////////////////////////////////////////////
-(NSString*)convertToString
{
    return [self convertHelper:self];
}
//////////////////////////////////////////////////////////////////////////////////////
-(NSArray*)findElements:(NSString*)tag root:(XMLElement*)root array:(NSMutableArray*)array
{
    if([root.name isEqualToString:[tag lowercaseString]])
    {
        if(!array)
            array = [[NSMutableArray alloc] init];
        if(![array containsObject:root])
            [array addObject:root];
    }
    for(XMLElement* child in root.childern)
    {
        NSArray* found = [self findElements:tag root:child array:array];
        if(found && !array)
            array = [NSMutableArray arrayWithArray:found];
        //[array addObjectsFromArray:found];
    }
    return array;
}
//////////////////////////////////////////////////////////////////////////////////////
-(NSArray*)findElements:(NSString*)tag
{
    NSMutableArray* array = nil;
    return [self findElements:tag root:self array:array];
}
//////////////////////////////////////////////////////////////////////////////////////
-(XMLElement*)findElement:(NSString*)tag
{
    NSArray* array = [self findElements:tag];
    if(array && array.count > 0)
        return [array objectAtIndex:0];
    return nil;
}
//////////////////////////////////////////////////////////////////////////////////////
@end
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
@interface XMLKit()

-(void)didStartElement:(NSString*)tag attributes:(NSDictionary*)attributeDict;
-(void)foundCharacters:(NSString*)string;
-(void)didEndElement:(NSString*)tag;
-(void)documentDidEnd;

@end

//////////////////////////////////////////////////////////////////////////////////////
@implementation XMLKit

static void elementDidStart(void *ctx,const xmlChar *name,const xmlChar **atts);
static void foundChars(void *ctx,const xmlChar *ch,int len);
static void elementDidEnd(void *ctx,const xmlChar *name);
static void documentDidEnd(void *ctx);
static void error( void * ctx, const char * msg, ... );


//////////////////////////////////////////////////////////////////////////////////////
+(XMLElement*)ParseXMLString:(NSString*)string
{
    XMLKit* kit = [[[XMLKit alloc] init] autorelease];
    return [kit parse:string];
}
//////////////////////////////////////////////////////////////////////////////////////
-(XMLElement*)parse:(NSString*)xmlString
{
    xmlSAXHandler saxHandler;
    memset( &saxHandler, 0, sizeof(saxHandler) );
    saxHandler.startElement = &elementDidStart;
    saxHandler.endElement = &elementDidEnd;
    saxHandler.characters = &foundChars;
    saxHandler.endDocument = &documentDidEnd;
    saxHandler.error = &error;
    xmlSAXUserParseMemory(&saxHandler,self,[xmlString UTF8String], (int)[xmlString length]);
    //rootElement.isValid = isValid;
    if(isValid)
        return rootElement;
    return nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//private
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
//c functions that forward to objective c functions
///////////////////////////////////////////////////////////////////////////////////////////////////
void elementDidStart(void *ctx,const xmlChar *name,const xmlChar **atts)
{
    NSString* elementName = [NSString stringWithCString:(const char*)name encoding:NSUTF8StringEncoding];
    NSMutableDictionary* collect = nil;
    
    if(atts)
    {
        const xmlChar *attrib = NULL;
        collect = [NSMutableDictionary dictionary];
        int i = 0;
        NSString* key = @"";
        do
        {
            attrib = *atts;
            if(!attrib)
                break;
            if(i % 2 != 0 && i != 0)
            {
                NSString* val = [NSString stringWithCString:(const char*)attrib encoding:NSUTF8StringEncoding];
                [collect setObject:val forKey:key];
            }
            else
                key = [NSString stringWithCString:(const char*)attrib encoding:NSUTF8StringEncoding];
            atts++;
            i++;
        }while(attrib != NULL);
    }
    
    NSString* tag = [elementName lowercaseString];
    //NSLog(@"collect: %@",collect);
    XMLKit* parser = (XMLKit*)ctx;
    [parser didStartElement:tag attributes:collect];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
void foundChars(void *ctx,const xmlChar *ch,int len)
{
    NSString* string = [NSString stringWithCString:(const char*)ch encoding:NSUTF8StringEncoding];
    XMLKit* parser = (XMLKit*)ctx;
    [parser foundCharacters:string];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
void elementDidEnd(void *ctx,const xmlChar *name)
{
    NSString* elementName = [NSString stringWithCString:(const char*)name encoding:NSUTF8StringEncoding];
    NSString* tag = [elementName lowercaseString];
    XMLKit* parser = (XMLKit*)ctx;
    [parser didEndElement:tag];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
void documentDidEnd(void *ctx)
{
    XMLKit* parser = (XMLKit*)ctx;
    [parser documentDidEnd];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
void error( void * ctx, const char * msg, ... )
{
    //NSLog(@"got error parsing");
}
///////////////////////////////////////////////////////////////////////////////////////////////////
//objective c function from c functions above
///////////////////////////////////////////////////////////////////////////////////////////////////
-(void)didStartElement:(NSString*)tag attributes:(NSDictionary*)attributeDict
{
    NSString* name = [tag lowercaseString];
    //NSLog(@"tag: %@ attrib: %@",tag,attributeDict);
    XMLElement* element = [XMLElement elementWithName:name attributes:attributeDict];
    if(!rootElement)
        rootElement = [element retain];
    else
    {
        element.parent = currentElement;
        [currentElement.childern addObject:element];
    }
    currentElement = element;
        
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(void)foundCharacters:(NSString*)string
{
    currentElement.text = string;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(void)didEndElement:(NSString*)tag
{
    currentElement = currentElement.parent;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(void)documentDidEnd
{
    if([currentElement.name isEqualToString:rootElement.name] || !currentElement)
        isValid = YES;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(void)printElement:(XMLElement*)element
{
    for(XMLElement* child in element.childern)
    {
        NSLog(@"<%@>%@</%@>",child.name,child.text,child.name);
        [self printElement:child];
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////////

@end

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation NSString (XMLKit)

///////////////////////////////////////////////////////////////////////////////////////////////////
-(XMLElement*)XMLObjectFromString
{
    return [XMLKit ParseXMLString:self];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)stripXMLTags
{
    NSRange r;
    NSString *s = self;
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s;
}
///////////////////////////////////////////////////////////////////////////////////////////////////

@end
