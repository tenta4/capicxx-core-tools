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
            («fField.getTypeName(fInterface, true)»)
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

        #endif // «fInterface.defineName»_SERRIALIZATION_HPP_
    '''

    def private extCommandTypeName(FInterface fInterface) '''
        SCommand«fInterface.name»'''

    def private extVersionTypeName(FInterface fInterface) '''
        SVersion«fInterface.name»'''

    def private extGenerateDumpClientWriter(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once

        #include <fstream>

        #include <«fInterface.proxyDumpWrapperHeaderPath»>
        #include <«fInterface.serrializationHeaderPath»>

        struct «fInterface.extCommandTypeName()» {
            int64_t time;
            std::string name;
        };

        struct «fInterface.extVersionTypeName()» {
            uint32_t major;
            uint32_t minor;
        };

        ADAPT_NAMED_ATTRS_ADT(
        «fInterface.extCommandTypeName()»,
        ("time", time)
        ("name", name),
        SIMPLE_ACCESS)

        ADAPT_NAMED_ATTRS_ADT(
        «fInterface.extVersionTypeName()»,
        ("major", major)
        ("minor", minor),
        SIMPLE_ACCESS)

        class «fInterface.proxyDumpWriterClassName»
        {
        public:
            «fInterface.proxyDumpWriterClassName»(const std::string& file_name)
            {
                m_stream.open(file_name.c_str());
                if (!m_stream.is_open())
                {
                    throw std::runtime_error("Failed to open file '" + file_name + "'");
                }

                boost::property_tree::ptree child_ptree;

                «fInterface.extVersionTypeName()» version{«fInterface.version.major», «fInterface.version.minor»};
                DataSerializer::Private::TPtreeSerializer<«fInterface.extVersionTypeName()»>::write(version, child_ptree);

                m_stream << "{\n\"" << "version" << "\": ";
                boost::property_tree::write_json(m_stream, child_ptree);
                m_stream << ",\"queries\": [\n";
            }

            ~«fInterface.proxyDumpWriterClassName»()
            {
                finishQuery(true);
                m_stream << "]\n}";
            }

            void beginQuery(const std::string& name)
            {
                if (!m_current_ptree.empty())
                {
                    finishQuery();
                }

                int64_t us = std::chrono::duration_cast<std::chrono::microseconds>(
                    std::chrono::system_clock::now().time_since_epoch()).count();

                boost::property_tree::ptree child_ptree;
                DataSerializer::Private::TPtreeSerializer<«fInterface.extCommandTypeName()»>::write({us, name}, child_ptree);

                m_current_ptree.add_child("declaration", child_ptree);
                child_ptree.clear();

                m_current_ptree.add_child("params", child_ptree);
            }

            template<class T>
            void adjustQuery(const T& var, const std::string& name)
            {
                boost::property_tree::ptree& data_ptree = m_current_ptree.get_child("params");
                boost::property_tree::ptree child_ptree;
                DataSerializer::Private::TPtreeSerializer<T>::write(var, child_ptree);
                data_ptree.add_child(name, child_ptree);
            }

            void finishQuery(bool last = false)
            {
                boost::property_tree::write_json(m_stream, m_current_ptree);
                if (!last)
                {
                    m_stream << ",";
                }
                m_current_ptree.clear();
            }

        private:
            std::ofstream m_stream;
            boost::property_tree::ptree m_current_ptree;
        };
    '''

    def private extGenerateDumpClientWrapper(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once
        #include <«fInterface.proxyHeaderPath»>
        #include <«fInterface.proxyDumpWriterHeaderPath»>

        «generateNativeInjection(fInterface.name, 'DUMPER_INCLUDES', '//')»

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

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
            «fInterface.proxyDumpWrapperClassName»(std::shared_ptr<CommonAPI::Proxy> delegate)
                : «fInterface.proxyClassName»<_AttributeExtensions...>(delegate)
                , m_writer("«fInterface.name»_dump.json")
            {
                std::cout << "Version : «fInterface.version.major».«fInterface.version.minor»" << std::endl;

                «FOR fAttribute : fInterface.attributes»
                    «fInterface.proxyClassName»<_AttributeExtensions...>::get«fAttribute.className»().
                        getChangedEvent().subscribe([this](const «fAttribute.getTypeName(fInterface, true)»& data)
                        {
                            «generateNativeInjection(fInterface.name + '_' + fAttribute.name, 'WRITE', '//')»

                            // TODO: add mutex?
                            m_writer.beginQuery("«fAttribute.className»");
                            m_writer.adjustQuery(data, "«fAttribute.name»");
                        });
                «ENDFOR»
                «FOR broadcast : fInterface.broadcasts»
                    «fInterface.proxyClassName»<_AttributeExtensions...>::get«broadcast.className»().subscribe([this](
                        «var boolean first = true»
                        «FOR argument : broadcast.outArgs»
                            «IF !first»,«ENDIF»«{first = false; ""}» const «argument.getTypeName(argument, true)»& «argument.name»
                        «ENDFOR»
                        ) {
                            // TODO: add mutex?
                            m_writer.beginQuery("«broadcast.className»");
                            «FOR argument : broadcast.outArgs»
                                «generateNativeInjection(fInterface.name + '_' + argument.name, 'WRITE', '//')»
                                m_writer.adjustQuery(«argument.name», "«argument.name»");
                            «ENDFOR»
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

        private:
            «fInterface.proxyDumpWriterClassName» m_writer;
        };

        «FOR method : fInterface.methods»
            «IF generateSyncCalls || method.isFireAndForget»
            template <typename ... _AttributeExtensions>
            «method.generateDefinitionWithin(fInterface.proxyDumpWrapperClassName + '<_AttributeExtensions...>', false)» {
                std::cout << "«method.name» call" << std::endl;
                «fInterface.proxyClassName»<_AttributeExtensions...>::«method.name»(
                    «method.generateMethodArgumentList»
                );
                m_writer.beginQuery("«method.name»");
                «FOR argument : method.inArgs»
                    m_writer.adjustQuery(_«argument.name», "«argument.name»");
                «ENDFOR»
                «FOR argument : method.outArgs»
                    m_writer.adjustQuery(_«argument.name», "«argument.name»");
                «ENDFOR»
                «IF (method.hasError)»
                    m_writer.adjustQuery(_error, "_error");
                «ENDIF»
            }

            «ENDIF»
            «IF !method.isFireAndForget»
                template <typename ... _AttributeExtensions>
                «method.generateAsyncDefinitionWithin(fInterface.proxyDumpWrapperClassName + '<_AttributeExtensions...>', false)» {
                    std::cout << "call «method.name» ASYNC" << std::endl;

                    «method.asyncCallbackClassName» cb_wrapper = [=](«method.generateASyncTypedefSignature(true)»)
                    {
                        std::cout << "callback getRoute ASYNC" << std::endl;
                        _callback(«method.generateASyncTypedefAguments»);

                        m_writer.beginQuery("«method.elementName»Async");
                        «FOR arg : method.inArgs»
                            m_writer.adjustQuery(_«arg.name», "«arg.name»");
                        «ENDFOR»
                        «FOR arg : method.outArgs»
                            m_writer.adjustQuery(«arg.name», "«arg.name»");
                        «ENDFOR»
                        «IF (method.hasError)»
                            m_writer.adjustQuery(error, "_error");
                        «ENDIF»
                    };

                    return «fInterface.proxyClassName»<_AttributeExtensions...>::«method.name»Async(«method.generateAsyncMethodArguments»);
                }
            «ENDIF»
        «ENDFOR»

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»
    '''

    def private generateDumperMain(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #include <csignal>
        #include <iostream>
        #include <unistd.h>

        #include <CommonAPI/CommonAPI.hpp>

        #include <«fInterface.proxyDumpWrapperHeaderPath»>

        template<template<typename ...> class T>
        class TCommonWrapper
        {
        public:
        TCommonWrapper(const std::string& domain, const std::string& instance, uint32_t retry_count)
        {
            std::shared_ptr <CommonAPI::Runtime> runtime = CommonAPI::Runtime::get();
            m_proxy = runtime->buildProxy<T>(domain.c_str(), instance.c_str());
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
        }
        protected:
            std::shared_ptr<T<>> m_proxy;
        };

        «fInterface.generateNamespaceUsage»

        std::atomic<bool> done(false);
        void signalHandler(int signum) {
            done = true;
        }

        int main(int argc, char** argv)
        {
            «fInterface.generateNamespaceUsage»

            if (argc < 2) {
                std::cout << "Input service name please" << std::endl;
                return 0;
            }

            std::string service_name = argv[1];
            std::cout << "Service name: " << service_name << std::endl;

            signal(SIGINT, signalHandler);

            typedef TCommonWrapper<«fInterface.proxyDumpWrapperClassName»> ProxyDumpWraper;
            std::shared_ptr<ProxyDumpWraper> perception_proxy = std::make_shared<ProxyDumpWraper>(
                        "local", service_name, 5);

            while (!done) {
                sleep(1);
            }

            return 0;
        }
    '''
}
