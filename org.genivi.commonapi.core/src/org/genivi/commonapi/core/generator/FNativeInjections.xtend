package org.genivi.commonapi.core.generator

import java.util.Map
import java.util.HashMap

import org.franca.core.franca.FAnnotationType
import org.franca.core.franca.FInterface

class FNativeInjections {

    val Map<String, String> native_injections = new HashMap<String, String>()

    def String generateNativeInjection(String tag)
    {
        if (native_injections.containsKey(tag))
        {
            return native_injections.get(tag)
        }
        return ''
    }

    def String printInjections()
    {
        var String res = new String()
        for (entity: native_injections.entrySet())
        {
            res += entity.getKey() + "/" + entity.getValue() + System.getProperty("line.separator")
        }
        return res;
    }

    def private String getTagValue(String tag, String data)
    {
        val String openTag = '<'+tag+'>'
        val String closeTag = '</'+tag+'>'
        val open = data.indexOf(openTag);
        val close = data.indexOf(closeTag);

        val String comment = '// Native injection ' + tag + ':'
        if (open >= 0 && close > open)
        {
            return comment + data.substring(open + openTag.length(), close).replaceAll('<star/>', '*')
        }
        return comment + ' empty'
    }

    def fillInjections(FInterface fInterface)
    {
        if (fInterface.comment != null) {
            for (element : fInterface.comment.elements) {
                if (element.type == FAnnotationType::EXPERIMENTAL)
                {
                    native_injections.put(fInterface.name + '_' + 'DUMPER_INCLUDES', getTagValue('DUMPER_INCLUDES', element.comment));
                    //native_injections.put(fInterface.name + '_' + 'DUMPER_CONSTRUCTOR', getTagValue('DUMPER_CONSTRUCTOR', element.comment));
                    native_injections.put(fInterface.name + '_' + 'DUMPER_PRIVATE_MEMBERS', getTagValue('DUMPER_PRIVATE_MEMBERS', element.comment));

                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_INCLUDES', getTagValue('PLAYBACK_INCLUDES', element.comment));
                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_READER_CONSTRUCTOR', getTagValue('PLAYBACK_READER_CONSTRUCTOR', element.comment));
                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_READER_PRIVATE_MEMBERS', getTagValue('PLAYBACK_READER_PRIVATE_MEMBERS', element.comment));
                }
            }

            for (attribute : fInterface.attributes)
            {
                if (attribute.comment != null) {
                    for (element : attribute.comment.elements) {
                        if (element.type == FAnnotationType::EXPERIMENTAL) {
                            native_injections.put(fInterface.name + '_' + attribute.name + '_' + 'READ', getTagValue('READ', element.comment));
                            native_injections.put(fInterface.name + '_' + attribute.name + '_' + 'WRITE', getTagValue('WRITE', element.comment));
                        }
                    }
                }
            }

            for (method : fInterface.methods)
            {
                if (method.comment != null) {
                    for (element : method.comment.elements) {
                        if (element.type == FAnnotationType::EXPERIMENTAL) {
                            native_injections.put(fInterface.name + '_' + method.name + '_' + 'READ', getTagValue('READ', element.comment));
                            native_injections.put(fInterface.name + '_' + method.name + '_' + 'AFTER_SEND', getTagValue('AFTER_SEND', element.comment));
                        }
                    }
                }
            } // endfor
        } // endof fillInjections()
    }

}
