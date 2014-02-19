//////////////////////////////////////////////////////////////////////////////////////
//
//  XMLKit.h
//
//  Created by Dalton Cherry on 9/4/12.
//
//////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

/**
  Object representation of an XML element.
*/
@interface XMLElement : NSObject

///-------------------------------
/// @name element properties
///-------------------------------

/**
  Returns an array of children XMLElements.
*/
@property(nonatomic,retain)NSMutableArray* children;

/**
 Returns a dictionary of the element's attributes.
 */
@property(nonatomic,retain)NSMutableDictionary* attributes;

/**
 Returns the name of the element. So <luke></luke> would return luke.
 */
@property(nonatomic, copy)NSString* name;

/**
 Returns the text of the element. So <luke>Skywalker</luke> would return Skywalker.
 */
@property(nonatomic, copy)NSString* text;

/**
 Returns the parent XMLElement. Returns nil if root element.
 */
@property(nonatomic, retain)XMLElement* parent;

///-------------------------------
/// @name element instance methods
///-------------------------------

/**
 Returns string representation of XML element.
 */
-(NSString*)convertToString;

/**
 Finds first element with XML tag that is passed in. Returns nil if not found.
 */
-(XMLElement*)findElement:(NSString*)tag;

/**
 Finds all element with XML tag that is passed in. Returns empty array if not found.
 */
-(NSArray*)findElements:(NSString*)tag;

/**
 Creates an element with name (tag name) and attributes you want. Text is set to an empty string by default.
*/
+(XMLElement*)elementWithName:(NSString*)name attributes:(NSDictionary*)dict;

@end

/**
 Parsing string into XML Elements!
 */
@interface XMLKit : NSObject
{
    XMLElement* rootElement;
    XMLElement* currentElement;
    BOOL isValid;
}

/**
 Parses the string parameter and returns an XMLElement.
 */
+(XMLElement*)parseXMLString:(NSString*)string;

@end

/**
 Category methods NSString to interact with XML/HTML data/entities.
 */
@interface NSString (XMLKit)

///-------------------------------
/// @name NSString category methods
///-------------------------------

/**
 Creates an XMLElement from a string.
 */
-(XMLElement*)XMLObjectFromString;

/**
 strip all the XML/HTML tags from a string.
 */
-(NSString*)stripXMLTags;

/**
 Stripes XML/HTML comments from a string.
 */
-(NSString*)stripXMLComments;

/**
 Unescapes/decodes XML/HTML values. For example, '&amp;' becomes '&'.
 See gtm_stringByUnescapingFromHTML for more info.
 */
-(NSString*)decodeEntities;

/**
 Escapes/encodes XML/HTML values. For example, '&' become '&amp;'
 See stringByEscapingXML for more info.
 */
-(NSString*)encodeEntities;

@end
