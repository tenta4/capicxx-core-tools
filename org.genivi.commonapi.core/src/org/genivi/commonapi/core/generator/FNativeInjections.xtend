package org.genivi.commonapi.core.generator

import java.util.Map
import java.util.HashMap

import org.franca.core.franca.FAnnotationType
import org.franca.core.franca.FInterface

class FNativeInjections {

    val Map<String, String> native_injections = new HashMap<String, String>()
    val Map<String, String> options = new HashMap<String, String>()

    def String optionValue(String path, String tag)
    {
        var String value = '';
        val String full_path = path + '_' + tag
        if (options.containsKey(full_path))
        {
            value = options.get(full_path)
        }

        return value
    }

    def boolean isOptionContainsText(String path, String tag, String text)
    {
        var String option_value = optionValue(path, tag);
        if (option_value.indexOf(text) >= 0)
        {
            return true;
        }
        return false;
    }

    def String generateNativeInjection(String path, String tag, String comment_sym)
    {
        val String comment = comment_sym + ' Native injection ' + tag + ' : '
        val String full_path = path + '_' + tag
        var String injection = '';
        if (native_injections.containsKey(full_path))
        {
            injection = native_injections.get(full_path)
        }
        if (injection == '')
        {
            return comment + 'empty'
        }
        return comment + injection;
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

    def private String getTagValue(String tag, String data, String default_value)
    {
        val String openTag = '<'+tag+'>'
        val String closeTag = '</'+tag+'>'
        val open = data.indexOf(openTag);
        val close = data.indexOf(closeTag);

        if (open >= 0 && close > open)
        {
            return data.substring(open + openTag.length(), close).replaceAll('<star/>', '*')
        }
        return default_value
    }

    def fillInjections(FInterface fInterface)
    {
        if (fInterface.comment != null) {
            for (element : fInterface.comment.elements) {
                if (element.type == FAnnotationType::EXPERIMENTAL)
                {
                    native_injections.put(fInterface.name + '_' + 'DUMPER_INCLUDES', getTagValue('DUMPER_INCLUDES', element.comment, ''));
                    //native_injections.put(fInterface.name + '_' + 'DUMPER_CONSTRUCTOR', getTagValue('DUMPER_CONSTRUCTOR', element.comment, ''));
                    native_injections.put(fInterface.name + '_' + 'DUMPER_PRIVATE_MEMBERS', getTagValue('DUMPER_PRIVATE_MEMBERS', element.comment, ''));

                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_INCLUDES', getTagValue('PLAYBACK_INCLUDES', element.comment, ''));
                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_READER_CONSTRUCTOR', getTagValue('PLAYBACK_READER_CONSTRUCTOR', element.comment, ''));
                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_READER_PRIVATE_MEMBERS', getTagValue('PLAYBACK_READER_PRIVATE_MEMBERS', element.comment, ''));

                    native_injections.put(fInterface.name + '_' + 'DUMPER_LINK_LIBRARIES', getTagValue('DUMPER_LINK_LIBRARIES', element.comment, ''));
                    native_injections.put(fInterface.name + '_' + 'PLAYBACK_LINK_LIBRARIES', getTagValue('PLAYBACK_LINK_LIBRARIES', element.comment, ''));
                    native_injections.put(fInterface.name + '_' + 'CMAKE_END', getTagValue('CMAKE_END', element.comment, ''));

                    options.put(fInterface.name + '_' + 'OPTION_DUMPER_ENABLE', getTagValue('OPTION_DUMPER_ENABLE', element.comment, 'true'));
                    options.put(fInterface.name + '_' + 'OPTION_PLAYBACK_ENABLE', getTagValue('OPTION_PLAYBACK_ENABLE', element.comment, 'true'));
                    options.put(fInterface.name + '_' + 'DISABLED_FIELDS', getTagValue('DISABLED_FIELDS', element.comment, ''));
                }
            }
        }

        for (attribute : fInterface.attributes)
        {
            if (attribute.comment != null) {
                for (element : attribute.comment.elements) {
                    if (element.type == FAnnotationType::EXPERIMENTAL) {
                        native_injections.put(fInterface.name + '_' + attribute.name + '_' + 'READ', getTagValue('READ', element.comment, ''));
                        native_injections.put(fInterface.name + '_' + attribute.name + '_' + 'WRITE', getTagValue('WRITE', element.comment, ''));
                    }
                }
            }
        }

        for (method : fInterface.methods)
        {
            if (method.comment != null) {
                for (element : method.comment.elements) {
                    if (element.type == FAnnotationType::EXPERIMENTAL) {
                        native_injections.put(fInterface.name + '_' + method.name + '_' + 'READ', getTagValue('READ', element.comment, ''));
                        native_injections.put(fInterface.name + '_' + method.name + '_' + 'AFTER_SEND', getTagValue('AFTER_SEND', element.comment, ''));
                    }
                }
            }
        }
    }

}
