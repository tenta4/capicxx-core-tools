package org.genivi.commonapi.core.generator

import java.util.HashSet
import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor
import org.genivi.commonapi.core.preferences.PreferenceConstants
import org.genivi.commonapi.core.preferences.FPreferences

import org.franca.core.franca.FTypeRef
import org.franca.core.franca.FTypeCollection
import org.franca.core.franca.FStructType
import org.franca.core.franca.FTypeDef
import org.franca.core.franca.FArrayType
import org.franca.core.franca.FMapType
import org.franca.core.franca.FUnionType
import org.franca.core.franca.FEnumerationType

import org.franca.core.franca.FModelElement

class FInterfaceDumpGeneratorExtension {
    @Inject private extension FTypeGenerator
    @Inject private extension FrancaGeneratorExtensions
    @Inject private extension FNativeInjections

    var HashSet<FModelElement> usedTypes;
    var boolean generateSyncCalls = true

    def generateDumper(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid) {

        fInterface.fillInjections()
        usedTypes = new HashSet<FModelElement>
        generateSyncCalls = FPreferences::getInstance.getPreference(PreferenceConstants::P_GENERATE_SYNC_CALLS, "true").equals("true")
        fileSystemAccess.generateFile(fInterface.serrializationHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.extGenerateSerrialiation(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.proxyDumpWrapperHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.extGenerateDumpClientWrapper(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.proxyDumpWriterHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.extGenerateDumpClientWriter(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.dumperMainPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateDumperMain(deploymentAccessor, modelid))
    }

    def private getProxyDumpWrapperClassName(FInterface fInterface) {
        fInterface.proxyClassName + 'DumpWrapper'
    }

    def private getProxyDumpWriterClassName(FInterface fInterface) {
        fInterface.proxyClassName + 'DumpWriter'
    }

    def dispatch extGenerateTypeSerrialization(FTypeDef fTypeDef, FInterface fInterface) '''
        «extGenerateSerrializationMain(fTypeDef.actualType, fInterface)»
    '''

    def dispatch extGenerateTypeSerrialization(FArrayType fArrayType, FInterface fInterface) '''
        «extGenerateSerrializationMain(fArrayType.elementType, fInterface)»
    '''

    def dispatch extGenerateTypeSerrialization(FMapType fMap, FInterface fInterface) '''
        «extGenerateSerrializationMain(fMap.keyType, fInterface)»
        «extGenerateSerrializationMain(fMap.valueType, fInterface)»
    '''

    def dispatch extGenerateTypeSerrialization(FEnumerationType fEnumerationType, FInterface fInterface) '''
        «IF usedTypes.add(fEnumerationType)»
            #ifndef «fEnumerationType.getDefineName(fInterface)»
            #define «fEnumerationType.getDefineName(fInterface)»
            «(fEnumerationType.eContainer as FTypeCollection).generateVersionNamespaceBegin»
            «fEnumerationType.model.generateNamespaceBeginDeclaration»
            inline std::istream& operator>> (std::istream& s, «fEnumerationType.getElementName(fInterface, true)» & val) {
                std::string value;
                s >> value;

                static std::map<std::string, «fEnumerationType.getElementName(fInterface, true)»> conv_map = {
                «FOR element : fEnumerationType.enumerators»
                    {"«element.name»", «fEnumerationType.getElementName(fInterface, true)»::«element.name»},
                «ENDFOR»
                };

                auto item = conv_map.find(value);
                if (item == conv_map.end()) {
                    throw std::runtime_error("Read: Unexpected enum value : '" + value + "'");
                }
                val = item->second;

                return s;
            }

            inline std::ostream& operator<< (std::ostream& s, «fEnumerationType.getElementName(fInterface, true)» val) {
                static std::map<«fEnumerationType.getElementName(fInterface, true)», std::string> conv_map = {
                «FOR element : fEnumerationType.enumerators»
                    {«fEnumerationType.getElementName(fInterface, true)»::«element.name», "«element.name»"},
                «ENDFOR»
                };

                auto item = conv_map.find(val);
                if (item == conv_map.end()) {
                    throw std::runtime_error("Write: Unexpected enum value : '" + std::to_string(val) + "'");
                }
                s << item->second;
                return s;
            }
            «fEnumerationType.model.generateNamespaceEndDeclaration»
            «(fEnumerationType.eContainer as FTypeCollection).generateVersionNamespaceEnd»
            #endif // «fEnumerationType.getDefineName(fInterface)»
        «ENDIF»
    '''

    def dispatch extGenerateTypeSerrialization(FUnionType fUnionType, FInterface fInterface) '''
        «FOR fField : fUnionType.elements»
            «extGenerateSerrializationMain(fField.type, fInterface)»
        «ENDFOR»

        #ifndef BOOST«fUnionType.getDefineName(fInterface)»
        #define BOOST«fUnionType.getDefineName(fInterface)»
        DEFINE_BOOST_VARIANT(
        , Boost«fUnionType.name»,
        «FOR fField : fUnionType.elements»
            («fField.getTypeName(fInterface, true)», "T-«fField.getTypeName(fInterface, true).replace(':', '-')»")
        «ENDFOR»
        )
        #endif // BOOST«fUnionType.getDefineName(fInterface)»

        namespace DataSerializer {

            class my_visitor : public boost::static_visitor<«fUnionType.getElementName(fInterface, true)»>
            {
            public:
                template<class T>
                «fUnionType.getElementName(fInterface, true)» operator()(const T& i) const
                {
                    «fUnionType.getElementName(fInterface, true)» variant_value = i;
                    return variant_value;
                }
            };

            template<>
            struct TPtreeSerializeCustomPrimitive<«fUnionType.getElementName(fInterface, true)»> : std::true_type
            {
                static void read(«fUnionType.getElementName(fInterface, true)»& out, const boost::property_tree::ptree& ptree)
                {
                    Boost«fUnionType.name» v;
                    DataSerializer::Private::TPtreeSerializer<Boost«fUnionType.name»>::read(v, ptree);

                    out = boost::apply_visitor(my_visitor(), v);
                }
                static void write(const «fUnionType.getElementName(fInterface, true)»& in, boost::property_tree::ptree& ptree)
                {
                    Boost«fUnionType.name» v;
                    switch (in.getMaxValueType() - in.getValueType())
                        {
                        «var int counter = 0»
                        «FOR fField : fUnionType.elements»
                            case «counter»:
                                v = {in.get<«fField.getTypeName(fInterface, true)»>()};
                                break;
                                «{counter += 1; ""}»
                        «ENDFOR»
                    }

                    DataSerializer::Private::TPtreeSerializer<Boost«fUnionType.name»>::write(v, ptree);
                }
            };
        }

    '''

    def dispatch extGenerateTypeSerrialization(FStructType fStructType, FInterface fInterface) '''
        «IF usedTypes.add(fStructType)»
            «IF (fStructType.base != null)»
                «extGenerateTypeSerrialization(fStructType.base, fInterface)»
            «ENDIF»
            «FOR fField : fStructType.elements»
                «extGenerateSerrializationMain(fField.type, fInterface)»
            «ENDFOR»

            // «fStructType.name»
            #ifndef «fStructType.getDefineName(fInterface)»
            #define «fStructType.getDefineName(fInterface)»
            ADAPT_NAMED_ATTRS_ADT(
            «(fStructType as FModelElement).getElementName(fInterface, true)»,
            «extGenerateFieldsSerrialization(fStructType, fInterface)» ,)
            #endif // «fStructType.getDefineName(fInterface)»
        «ENDIF»
    '''

    def dispatch extGenerateFieldsSerrialization(FStructType fStructType, FInterface fInterface) '''
        «IF (fStructType.base != null)»
            «extGenerateFieldsSerrialization(fStructType.base, fInterface)»
        «ENDIF»
        «FOR fField : fStructType.elements»
            ("«fField.name»", «fField.name.toFirstUpper»)
        «ENDFOR»
    '''

    def dispatch extGenerateSerrializationMain(FTypeRef fTypeRef, FInterface fInterface) '''
        «IF fTypeRef.derived != null»
            «extGenerateTypeSerrialization(fTypeRef.derived, fInterface)»
        «ENDIF»
    '''

    def private extGenerateSerrialiation(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #ifndef «fInterface.defineName»_SERRIALIZATION_HPP_
        #define «fInterface.defineName»_SERRIALIZATION_HPP_

        #include "data_serializer/DataSerializer.hpp"
        #include "preprocessor/AdaptNamedAttrsAdt.hpp"

        «val generatedHeaders = new HashSet<String>»
        «val libraryHeaders = new HashSet<String>»

        «fInterface.generateRequiredTypeIncludes(generatedHeaders, libraryHeaders, true)»

        «FOR requiredHeaderFile : generatedHeaders.sort»
            #include <«requiredHeaderFile»>
        «ENDFOR»

        «fInterface.generateDumpTypes»

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
                «extGenerateSerrializationMain(attribute.type, fInterface)»
            «ENDIF»
        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            «FOR argument : broadcast.outArgs»
                «extGenerateSerrializationMain(argument.type, fInterface)»
            «ENDFOR»
        «ENDFOR»

        «FOR methods : fInterface.methods»
            «FOR argument : methods.inArgs»
                «extGenerateSerrializationMain(argument.type, fInterface)»
            «ENDFOR»
            «FOR argument : methods.outArgs»
                «extGenerateSerrializationMain(argument.type, fInterface)»
            «ENDFOR»

            «IF methods.hasError»
                «extGenerateTypeSerrialization(methods.errorEnum, fInterface)»
            «ENDIF»
        «ENDFOR»

        «fInterface.generateDumpTypesSerialization»

        struct «fInterface.dumperCommandTypeName» {
            int64_t time;
            std::string name;
        };

        struct «fInterface.dumperVersionTypeName» {
            uint32_t major;
            uint32_t minor;
        };

        ADAPT_NAMED_ATTRS_ADT(
        «fInterface.dumperCommandTypeName»,
        ("time", time)
        ("name", name),
        SIMPLE_ACCESS)

        ADAPT_NAMED_ATTRS_ADT(
        «fInterface.dumperVersionTypeName»,
        ("major", major)
        ("minor", minor),
        SIMPLE_ACCESS)

        // TODO: move this as constans into future cpp-file
        #define s_version_tag "version"
        #define s_header_tag "header"
        #define s_content_tag "content"
        #define s_queries_tag "queries"
        #define s_array_item_tag "item"

        #endif // «fInterface.defineName»_SERRIALIZATION_HPP_
    '''

    def private generateDumpTypes(FInterface fInterface) '''
        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

        // classes for service's attributes
        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            struct «attribute.name»DumpType
            {
                «attribute.getTypeName(fInterface, true)» m_data;
            }; // class «attribute.name»DumpType

            «ENDIF»
        «ENDFOR»

        // classes for service's broadcasts
        «FOR broadcast : fInterface.broadcasts»
            struct «broadcast.name»DumpType
            {
                «FOR argument : broadcast.outArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
            }; // class «broadcast.name»DumpType

        «ENDFOR»

        // classes for service's methods
        «FOR method : fInterface.methods»
            struct «method.name»DumpType
            {
                «FOR argument : method.inArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
                «FOR argument : method.outArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
                «IF (method.hasError)»
                    «method.getErrorNameReference(method.eContainer)» m_error;
                «ENDIF»
            }; // class «method.name»DumpType

        «ENDFOR»

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»

    '''

    def private generateDumpTypesSerialization(FInterface fInterface) '''
        // adapts for service's attributes
        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
                ADAPT_NAMED_ATTRS_ADT(
                «fInterface.versionPrefix»«fInterface.model.generateCppNamespace»«attribute.name»DumpType,
                ("m_data", m_data)
                , SIMPLE_ACCESS)

            «ENDIF»
        «ENDFOR»

        // adapts for service's broadcasts
        «FOR broadcast : fInterface.broadcasts»
            ADAPT_NAMED_ATTRS_ADT(
            «fInterface.versionPrefix»«fInterface.model.generateCppNamespace»«broadcast.name»DumpType,
            «FOR argument : broadcast.outArgs»
                ("m_«argument.name»", m_«argument.name»)
            «ENDFOR»
            , SIMPLE_ACCESS)

        «ENDFOR»

        // adapts for service's methods
        «FOR method : fInterface.methods»
            ADAPT_NAMED_ATTRS_ADT(
            «fInterface.versionPrefix»«fInterface.model.generateCppNamespace»«method.name»DumpType,
            «FOR argument : method.inArgs»
                ("m_«argument.name»", m_«argument.name»)
            «ENDFOR»
            «FOR argument : method.outArgs»
                ("m_«argument.name»", m_«argument.name»)
            «ENDFOR»
            «IF (method.hasError)»
                ("m_error", m_error)
            «ENDIF»
            , SIMPLE_ACCESS)

        «ENDFOR»
    '''

    def private extGenerateDumpClientWriter(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once

        #include <fstream>

        #include <timeService/CTimeBase.hpp>

        #include <«fInterface.serrializationHeaderPath»>

        class CTagPrinter
        {
        public:
            static void open(std::ofstream& stream, const char* name)  {
                stream << "<" << name << ">" << std::endl;
            }

            static void close(std::ofstream& stream, const char* name) {
                stream << "</" << name << ">" << std::endl;
            }
        };

        class «fInterface.proxyDumpWriterClassName»
        {
        public:
            «fInterface.proxyDumpWriterClassName»(const std::string& file_name, bool is_system_time)
                : m_is_system_time(is_system_time)
            {
                m_stream.open(file_name.c_str());
                if (!m_stream.is_open())
                {
                    throw std::runtime_error("Failed to open file '" + file_name + "'");
                }

                «fInterface.dumperVersionTypeName» version{«fInterface.version.major», «fInterface.version.minor»};
                DataSerializer::writeXmlToStream(m_stream, version, s_version_tag, true, false);

                CTagPrinter::open(m_stream, s_queries_tag);
            }

            ~«fInterface.proxyDumpWriterClassName»()
            {
                CTagPrinter::close(m_stream, s_queries_tag);
            }

            template<class T>
            void write(const T& var, const std::string& name)
            {
                std::lock_guard<std::mutex> guard(m_write_mutex);
                CTagPrinter::open(m_stream, s_array_item_tag);
                int64_t us;
                if (m_is_system_time) {
                    us = std::chrono::duration_cast<std::chrono::microseconds>(
                       std::chrono::system_clock::now().time_since_epoch()).count();
                } else {
                    us = m_time.getCurrentTime();
                }
                DataSerializer::writeXmlToStream(m_stream, «fInterface.dumperCommandTypeName»{us, name}, s_header_tag, true, false);
                DataSerializer::writeXmlToStream(m_stream, var, s_content_tag, true, false);
                CTagPrinter::close(m_stream, s_array_item_tag);
            }

        private:
            std::ofstream m_stream;
            std::mutex m_write_mutex;

            TimeService::CTimeBase m_time;
            bool m_is_system_time;
        };
    '''

    def private extGenerateDumpClientWrapper(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once
        #include <«fInterface.proxyHeaderPath»>
        #include <«fInterface.proxyDumpWriterHeaderPath»>

        «generateNativeInjection(fInterface.name, 'DUMPER_INCLUDES', '//')»

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

        class «fInterface.name»WorkersCounter
        {
        public:
            «fInterface.name»WorkersCounter(std::atomic<unsigned>& in) : m_counter(in) { ++m_counter; }
            ~«fInterface.name»WorkersCounter() { --m_counter;}
        private:
            std::atomic<unsigned>& m_counter;
        };

        template <typename ..._AttributeExtensions>
        class «fInterface.proxyDumpWrapperClassName» : public «fInterface.proxyClassName»<_AttributeExtensions...>
        {
            «FOR method : fInterface.methods»
                «IF !method.isFireAndForget»
                    typedef typename «fInterface.proxyClassName»<_AttributeExtensions...>::«method.asyncCallbackClassName» «method.asyncCallbackClassName»;
                «ENDIF»
            «ENDFOR»
            «generateNativeInjection(fInterface.name, 'DUMPER_PRIVATE_MEMBERS', '//')»
        public:
            «fInterface.proxyDumpWrapperClassName»(std::shared_ptr<CommonAPI::Proxy> delegate, bool system_time = false)
                : «fInterface.proxyClassName»<_AttributeExtensions...>(delegate)
                , m_writer("«fInterface.name»_dump.xml", system_time)
                , m_workers_count(0)
            {
                std::cout << "Version : «fInterface.version.major».«fInterface.version.minor»" << std::endl;

                «FOR fAttribute : fInterface.attributes»
                    m_subscribe_«fAttribute.name» =
                    «fInterface.proxyClassName»<_AttributeExtensions...>::get«fAttribute.className»().
                        getChangedEvent().subscribe([this](const «fAttribute.getTypeName(fInterface, true)»& data)
                        {
                            «fInterface.name»WorkersCounter auto_count(m_workers_count);

                            «generateNativeInjection(fInterface.name + '_' + fAttribute.name, 'WRITE', '//')»

                            «fAttribute.name»DumpType dump_data{data};
                            m_writer.write(dump_data, "«fAttribute.name»Attribute");
                        });
                «ENDFOR»
                «FOR fBroadcast : fInterface.broadcasts»
                    m_subscribe_«fBroadcast.name» =
                    «fInterface.proxyClassName»<_AttributeExtensions...>::get«fBroadcast.className»().subscribe([this](
                        «var boolean first = true»
                        «FOR argument : fBroadcast.outArgs»
                            «IF !first»,«ENDIF»«{first = false; ""}» const «argument.getTypeName(argument, true)»& «argument.name»
                        «ENDFOR»
                        ) {
                            «fInterface.name»WorkersCounter auto_count(m_workers_count);

                            «generateNativeInjection(fInterface.name + '_' + fBroadcast.name, 'WRITE', '//')»

                            «{first = true; ""}»
                            «fBroadcast.name»DumpType dump_data{
                            «FOR argument : fBroadcast.outArgs»
                                «IF !first»,«ENDIF»«{first = false; ""}» «argument.name»
                            «ENDFOR»
                            };
                            m_writer.write(dump_data, "«fBroadcast.name»");
                        });
                «ENDFOR»
            }

            «FOR method : fInterface.methods»
                «IF generateSyncCalls || method.isFireAndForget»
                    virtual «method.generateDefinition(true)»;

                «ENDIF»
                «IF !method.isFireAndForget»
                    virtual «method.generateAsyncDefinition(true)»;

                «ENDIF»
            «ENDFOR»

            ~«fInterface.proxyDumpWrapperClassName»()
            {
                «FOR fAttribute : fInterface.attributes»
                    «fInterface.proxyClassName»<_AttributeExtensions...>::get«fAttribute.className»().
                        getChangedEvent().unsubscribe(m_subscribe_«fAttribute.name»);
                «ENDFOR»
                «FOR fBroadcast : fInterface.broadcasts»
                    «fInterface.proxyClassName»<_AttributeExtensions...>::get«fBroadcast.className»().
                        unsubscribe(m_subscribe_«fBroadcast.name»);
                «ENDFOR»

                while (m_workers_count > 0) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }
            }

        private:
            «FOR fAttribute : fInterface.attributes»
                CommonAPI::Event<«fAttribute.getTypeName(fInterface, true)»>::Subscription m_subscribe_«fAttribute.name»;
            «ENDFOR»
            «FOR fBroadcast : fInterface.broadcasts»
                CommonAPI::Event<«fBroadcast.outArgs.map[getTypeName(fInterface, true)].join(', ')»>::Subscription m_subscribe_«fBroadcast.name»;
            «ENDFOR»

            «fInterface.proxyDumpWriterClassName» m_writer;
            std::atomic<unsigned> m_workers_count;
        };

        «FOR method : fInterface.methods»
            «IF generateSyncCalls || method.isFireAndForget»
            template <typename ... _AttributeExtensions>
            «method.generateDefinitionWithin(fInterface.proxyDumpWrapperClassName + '<_AttributeExtensions...>', false)» {
                std::cout << "«method.name» call" << std::endl;
                «fInterface.proxyClassName»<_AttributeExtensions...>::«method.name»(
                    «method.generateMethodArgumentList»
                );

                «var boolean first = true»
                «method.name»DumpType dump_data{
                    «FOR argument : method.inArgs»
                        «IF !first»,«ENDIF»«{first = false; ""}» _«argument.elementName»
                    «ENDFOR»
                    «FOR argument : method.outArgs»
                        «IF !first»,«ENDIF»«{first = false; ""}» _«argument.elementName»
                    «ENDFOR»
                    «IF (method.hasError)»
                        «IF !first»,«ENDIF»«{first = false; ""}» _error
                    «ENDIF»
                };
                m_writer.write(dump_data, "«method.name»");
            }

            «ENDIF»
            «IF !method.isFireAndForget»
                template <typename ... _AttributeExtensions>
                «method.generateAsyncDefinitionWithin(fInterface.proxyDumpWrapperClassName + '<_AttributeExtensions...>', false)» {
                    std::cout << "call «method.name» ASYNC" << std::endl;

                    «method.asyncCallbackClassName» cb_wrapper = [=](«method.generateASyncTypedefSignature(true)»)
                    {
                        std::cout << "callback «method.name» ASYNC" << std::endl;
                        _callback(«method.generateASyncTypedefAguments»);

                        «var boolean first = true»
                        «method.name»DumpType dump_data{
                            «FOR argument : method.inArgs»
                                «IF !first»,«ENDIF»«{first = false; ""}» _«argument.elementName»
                            «ENDFOR»
                            «FOR argument : method.outArgs»
                                «IF !first»,«ENDIF»«{first = false; ""}» _«argument.elementName»
                            «ENDFOR»
                            «IF (method.hasError)»
                                «IF !first»,«ENDIF»«{first = false; ""}» _error
                            «ENDIF»
                        };
                        m_writer.write(dump_data, "«method.name»");
                    };

                    return «fInterface.proxyClassName»<_AttributeExtensions...>::«method.name»Async(«method.generateAsyncMethodArguments»);
                }
            «ENDIF»
        «ENDFOR»

        /* This is a slightly strange way to pass is_system_time flag.
         * It's necessary because there is no possibility to extend parameters list
         * for Proxy. It hardcoded in CommonAPI::Runtime::buildProxy method.
         */
        template <typename ..._AttributeExtensions>
        class «fInterface.proxyDumpWrapperClassName»_SystemTime :
                public «fInterface.proxyDumpWrapperClassName»<_AttributeExtensions...>
        {
        public:
            «fInterface.proxyDumpWrapperClassName»_SystemTime(std::shared_ptr<CommonAPI::Proxy> delegate)
                : «fInterface.proxyDumpWrapperClassName»<_AttributeExtensions...>(delegate, true){}
        };

        template <typename ..._AttributeExtensions>
        using «fInterface.proxyDumpWrapperClassName»_TimeService = «fInterface.proxyDumpWrapperClassName»<_AttributeExtensions...>;

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»
    '''

    def private generateDumperMain(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #include <csignal>
        #include <iostream>
        #include <unistd.h>

        #include <CommonAPI/CommonAPI.hpp>

        #include <«fInterface.proxyDumpWrapperHeaderPath»>

        class DumpProxyFactory
        {
        public:
            template<template<typename ...> class T> static
            std::shared_ptr<T<>> create(const std::string& domain, const std::string& instance, uint32_t retry_count)
            {
                std::shared_ptr <CommonAPI::Runtime> runtime = CommonAPI::Runtime::get();
                auto m_proxy = runtime->buildProxy<T>(domain.c_str(), instance.c_str());
                if (!m_proxy)
                {
                    throw std::runtime_error(instance + " : failed to create ");
                }

                while (retry_count && !m_proxy->isAvailable())
                {
                    retry_count--;
                    std::cout << std::endl << instance << " : try co connect " << std::endl;
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                }

                if (!retry_count) {
                    throw std::runtime_error(instance + " : service is not available");
                }

                return m_proxy;
            }
        };

        std::atomic<bool> done(false);
        void signalHandler(int signum) {
            done = true;
        }

        int main(int argc, char** argv)
        {
            «fInterface.generateNamespaceUsage»

            // TODO: rewrite to program options
            if (argc < 2) {
                std::cout << "Format <service name> "
                          << "[systemTime/timeService (default timeService)]"
                          << std::endl;
                return 0;
            }
            std::string service_name = argv[1];
            std::cout << "Service name: " << service_name << std::endl;

            signal(SIGINT, signalHandler);

            std::shared_ptr<«fInterface.proxyDumpWrapperClassName»<>> proxy;
            if (argc > 2 && std::string("systemTime") == argv[2])
            {
                proxy = DumpProxyFactory::create<«fInterface.proxyDumpWrapperClassName»_SystemTime>(
                        "local", service_name, 5);
            } else {
                proxy = DumpProxyFactory::create<«fInterface.proxyDumpWrapperClassName»_TimeService>(
                        "local", service_name, 5);
            }

            while (!done) {
                sleep(1);
            }

            return 0;
        }
    '''
}
