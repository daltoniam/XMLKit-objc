//////////////////////////////////////////////////////////////////////////////////////
//
//  XMLKit.m
//
//  Created by Dalton Cherry on 9/4/12.
//
//////////////////////////////////////////////////////////////////////////////////////

#import "XMLKit.h"
#import "GTMNSString+HTML.h"

@interface XMLElement()

@property(nonatomic, assign)NSInteger end;

@end

@implementation XMLElement

//////////////////////////////////////////////////////////////////////////////////////
+(XMLElement*)elementWithName:(NSString*)name attributes:(NSDictionary*)dict
{
    XMLElement* element = [[XMLElement alloc] init];
    element.name = name;
    element.attributes = [NSMutableDictionary dictionaryWithDictionary:dict];
    element.children = [NSMutableArray array];
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
    for(XMLElement* child in element.children)
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
    for(XMLElement* child in root.children)
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

@end

//////////////////////////////////////////////////////////////////////////////////////
@implementation XMLKit

//////////////////////////////////////////////////////////////////////////////////////
+(XMLElement*)parseXMLString:(NSString*)string
{
    XMLElement* rootElement = nil;
    XMLElement* currentElement = nil;
    NSInteger offset = 0;
    NSInteger len = [string length];
    while (offset > -1)
    {
        NSRange range = [string rangeOfString:@"<" options:0 range:NSMakeRange(offset, len-offset)];
        NSInteger start = range.location;
        if(start < 0 || range.location == NSNotFound)
            break;
        range = [string rangeOfString:@">" options:0 range:NSMakeRange(start, len-start)];
        NSInteger end = range.location;
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
                    if([element.name isEqualToString:currentElement.name] && currentElement.children.count == 0)
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
                //NSLog(@"start tag: %@ attributes: %@",element.name,element.attributes);
                element.end = end;
                if(!rootElement)
                    rootElement = element;
                else
                {
                    element.parent = currentElement;
                    if(currentElement)
                        [currentElement.children addObject:element];
                }
                if([string characterAtIndex:end-2] == '/') //this must be a self closing element
                {
                    //NSLog(@"self close end tag: %@",element.name);
                    //if(currentElement)
                    //    currentElement = currentElement.parent;
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
    //NSLog(@"text: %@",text);
    NSInteger offset = 1;
    if([text characterAtIndex:text.length-2] == '/')
        offset = 2;
    XMLElement* element = [[XMLElement alloc] init];
    NSRange range = [text rangeOfString:@" "];
    NSInteger fname = range.location;
    if(fname < 0 || range.location == NSNotFound)
        fname = text.length-1;
    else
    {
        NSString* attrString = [text substringWithRange:NSMakeRange(fname+1, (text.length-1)-(fname+offset))];
        NSArray* attrArray = [attrString componentsSeparatedByString:@" "];
        NSMutableArray* collect = [NSMutableArray arrayWithCapacity:attrArray.count];
        for(NSInteger i = 0; i < attrArray.count; i++)
        {
            NSString* string = [attrArray objectAtIndex:i];
            if(([string rangeOfString:@"="].location == NSNotFound || [string isEqualToString:@"="]) && collect.count > 0)
            {
                NSString* last = [collect lastObject];
                if([last characterAtIndex:last.length-1] == '\'' || [last characterAtIndex:last.length-1] == '\"')
                    [collect addObject:string];
                else
                {
                    last = [last stringByAppendingFormat:@" %@",string];
                    [collect removeLastObject];
                    [collect addObject:last];
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
    element.name = [[element.name stringByReplacingOccurrencesOfString:@"/" withString:@""] lowercaseString];
    element.children = [NSMutableArray array];
    //NSLog(@"element name: %@",element.name);
    //NSLog(@"attributes: %@",element.attributes);
    return element;
}
///////////////////////////////////////////////////////////////////////////////////////////////////

@end

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation NSString (XMLKit)

///////////////////////////////////////////////////////////////////////////////////////////////////
-(XMLElement*)XMLObjectFromString
{
    return [XMLKit parseXMLString:self];
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
-(NSString*)stripXMLComments
{
    NSRange r;
    NSString *s = self;
    while ((r = [s rangeOfString:@"<!--[^>]+-->" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)encodeEntities
{
    return [self stringByEscapingXML];
}
///////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)decodeEntities
{
    return [self gtm_stringByUnescapingFromHTML];
}
///////////////////////////////////////////////////////////////////////////////////////////////////

@end
