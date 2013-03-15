//
//  XMLKit.m
//  kqueue
//
//  Created by Dalton Cherry on 9/4/12.
//  Copyright (c) 2012 Lightspeed Systems. All rights reserved.
//

#import "XMLKit.h"
#import <libxml2/libxml/xmlreader.h>
#import "GTMNSString+HTML.h"

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
    NSString* textData = element.text;
    if(!textData)
        textData = @"";
    NSString* attribs = @"";
    for(id key in element.attributes)
        attribs = [attribs stringByAppendingFormat:@" %@=\"%@\"",key,[element.attributes objectForKey:key]];
    NSString* string = [NSString stringWithFormat:@"<%@%@>%@",element.name,attribs,textData];
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
            array = [NSMutableArray array];
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
    XMLElement* rootElement = nil;
    XMLElement* currentElement = nil;
    int offset = 0;
    int len = [string length];
    while (offset > -1)
    {
        NSRange range = [string rangeOfString:@"<" options:0 range:NSMakeRange(offset, len-offset)];
        int start = range.location;
        if(start < 0 || range.location == NSNotFound)
            break;
        range = [string rangeOfString:@">" options:0 range:NSMakeRange(start, len-start)];
        int end = range.location;
        if(end > 0 && range.location != NSNotFound)
            end += 1;
        offset = end;
        if(end > 0)
        {
            if([string characterAtIndex:start+1] == '!' || [string characterAtIndex:start+1] == '?') //we don't want this, going to skip them
            {
                continue;
            }
            if([string characterAtIndex:start+1] == '/') //must be a closing element
            {
                if(currentElement)
                {
                    NSString* tag = [string substringWithRange:NSMakeRange(start, end-start)];
                    XMLElement* element = [XMLKit parseElement:tag];
                    if([element.name isEqualToString:currentElement.name] && currentElement.childern.count == 0)
                    {
                        NSString* text = [string substringWithRange:NSMakeRange(currentElement.end, start-currentElement.end)];
                        currentElement.text = text;
                        //NSLog(@"element text: %@",text);
                    }
                    //NSLog(@"end tag: %@",element.name);
                    if(currentElement)
                        currentElement = currentElement.parent;
                }
            }
            else
            {
                NSString* tag = [string substringWithRange:NSMakeRange(start, end-start)]; 
                XMLElement* element = [XMLKit parseElement:tag];
                //NSLog(@"start tag: %@",element.name);
                element.end = end;
                if(!rootElement)
                    rootElement = element;
                else
                {
                    element.parent = currentElement;
                    if(currentElement)
                        [currentElement.childern addObject:element];
                }
                if([string characterAtIndex:end-2] == '/') //this must be a self closing element
                {
                    //NSLog(@"end tag: %@",element.name);
                    if(currentElement)
                        currentElement = currentElement.parent;
                }
                else
                    currentElement = element;
            }
        }
    }
    return rootElement;
}
//////////////////////////////////////////////////////////////////////////////////////
+(XMLElement*)parseElement:(NSString*)text
{
    NSLog(@"text: %@",text);
    int offset = 1;
    if([text characterAtIndex:text.length-2] == '/')
        offset = 2;
    XMLElement* element = [[[XMLElement alloc] init] autorelease];
    NSRange range = [text rangeOfString:@" "];
    int fname = range.location;
    if(fname < 0 || range.location == NSNotFound)
        fname = text.length-1;
    else
    {
        NSString* attrString = [text substringWithRange:NSMakeRange(fname+1, (text.length-1)-(fname+offset))];
        NSArray* attrArray = [attrString componentsSeparatedByString:@" "];
        NSLog(@"attrArray: %@",attrArray);
        NSMutableArray* collect = [NSMutableArray arrayWithCapacity:attrArray.count];
        for(int i = 0; i < attrArray.count; i++)
        {
            NSString* string = [attrArray objectAtIndex:i];
            if(([string rangeOfString:@"="].location == NSNotFound || [string isEqualToString:@"="]) && collect.count > 0)
            {
                NSString* last = [collect lastObject];
                if([last characterAtIndex:last.length-1] == '\'' || [last characterAtIndex:last.length-1] == '\"')
                    [collect addObject:string];
                else
                {
                    last = [last stringByAppendingString:string];
                    [collect replaceObjectAtIndex:i withObject:last];
                }
            }
            else
                [collect addObject:string];
        }
        if(collect.count > 0)
        {
            NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:attrArray.count];
            for(NSString* attr in collect)
            {
                NSRange split = [attr rangeOfString:@"="];
                if(split.location != NSNotFound)
                {
                    NSString* value = [attr substringWithRange:NSMakeRange(split.location+1, attr.length-(split.location+1))];
                    value = [value stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                    value = [value stringByReplacingOccurrencesOfString:@"'" withString:@""];
                    NSString* key = [attr substringWithRange:NSMakeRange(0, split.location)];
                    if(key.length > 0)
                    {
                        key = [key stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                        key = [key stringByReplacingOccurrencesOfString:@"'" withString:@""];
                        /*if(key.length > 1 && [key characterAtIndex:key.length-1] == '/')
                            key = [key substringToIndex:key.length-1];
                        if(value.length > 1 && [value characterAtIndex:value.length-1] == '/')
                            value = [value substringToIndex:key.length-1];*/
                        [dict setObject:value forKey:key];
                    }
                }
            }
            element.attributes = dict;
        }
    }
    element.name = [text substringWithRange:NSMakeRange(1, fname-1)];
    element.name = [element.name stringByReplacingOccurrencesOfString:@"/" withString:@""];
    element.childern = [NSMutableArray array];
    NSLog(@"element name: %@",element.name);
    NSLog(@"attributes: %@",element.attributes);
    return element;
}
//////////////////////////////////////////////////////////////////////////////////////
//-(XMLElement*)parse:(NSString*)xmlString
//{
    /*NSLog(@"xmlString: %@",xmlString);
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
    return nil;*/
    
     //xmlParserCtxtPtr xmlctx = NULL;
     //xmlctx = xmlCreatePushParserCtxt(&saxHandler,self, NULL, 0, NULL);
     //if (!xmlctx)
     //return nil;
     //if(!xmlParseChunk(xmlctx, [xmlString UTF8String], (int)[xmlString length], 0))
     //{
     //xmlFreeParserCtxt(xmlctx);
     //return nil;
     //}
     //xmlFreeParserCtxt(xmlctx);
//}
///////////////////////////////////////////////////////////////////////////////////////////////////

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
    if([currentElement.name isEqualToString:rootElement.name] || !currentElement || [currentElement.parent.name isEqualToString:rootElement.name])
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
-(NSString*)xmlSafe
{
    return [self gtm_stringByEscapingForAsciiHTML];
}
///////////////////////////////////////////////////////////////////////////////////////////////////

@end
