package org.genivi.commonapi.core.generator

import org.franca.core.franca.FMethod

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor
import org.genivi.commonapi.core.preferences.PreferenceConstants

class FInterfacePlaybackGeneratorExtension {
    @Inject private extension FrancaGeneratorExtensions
    @Inject private extension FNativeInjections
    @Inject private extension FJsonDumpReader

    def generatePlayback(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid) {

        fInterface.fillInjections()
        fileSystemAccess.generateFile(fInterface.playbackSourcePath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.extGeneratePlayback(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.dumpReaderHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateDumpReader(deploymentAccessor, modelid))
    }

    def private generateClientMethodCall(FMethod fMethod)
    {
        var signature = fMethod.inArgs.map['data.m_' + elementName].join(', ')
        if (!fMethod.inArgs.empty)
            signature = signature + ', '

        signature = signature + '_internalCallStatus'

        if (fMethod.hasError)
            signature = signature + ', _error'

        if (!fMethod.outArgs.empty)
            signature = signature + ', ' + fMethod.outArgs.map['data.m_' + elementName].join(', ')

        //if (!fMethod.fireAndForget) {
        //    signature += ", &_info"
        //}
        return 'm_transport->' + fMethod.name + '(' + signature + ')'
    }

    def private extGeneratePlayback(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #include <fstream>
        #include <iostream>
        #include <vector>
        #include <functional>

        #include "json_serializer/JsonSerializer.hpp"
        #include "preprocessor/AdaptNamedAttrsAdt.hpp"
        #include <«fInterface.serrializationHeaderPath»>
        #include <«fInterface.stubHeaderPath»>
        #include <«fInterface.proxyHeaderPath»>

        «generateNativeInjection(fInterface.name + "_PLAYBACK_INCLUDES")»

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
                class «attribute.name»Element;
            «ENDIF»
        «ENDFOR»
        «FOR broadcast : fInterface.broadcasts»
            class «broadcast.name»Element;
        «ENDFOR»
        «FOR method : fInterface.methods»
            class «method.name»Element;
        «ENDFOR»

        class IVisitor
        {
        public:
            «FOR attribute : fInterface.attributes»
                «IF attribute.isObservable»
                    virtual void visit_«attribute.name»(«attribute.name»Element&) = 0;
                «ENDIF»
            «ENDFOR»
            «FOR broadcast : fInterface.broadcasts»
                virtual void visit_«broadcast.name»(«broadcast.name»Element& data) = 0;
            «ENDFOR»
            «FOR method : fInterface.methods»
                virtual void visit_«method.name»(«method.name»Element& data) = 0;
            «ENDFOR»
        };

        class CServerVisitor : public IVisitor
        {
        public:
            CServerVisitor(std::shared_ptr<«fInterface.getStubClassName»> transport)
                : m_transport(transport) {}

            «FOR attribute : fInterface.attributes»
                «IF attribute.isObservable»
                    void visit_«attribute.name»(«attribute.name»Element&) override;
                «ENDIF»
            «ENDFOR»

            «FOR broadcast : fInterface.broadcasts»
                void visit_«broadcast.name»(«broadcast.name»Element& data) override;
            «ENDFOR»

            «FOR method : fInterface.methods»
                virtual void visit_«method.name»(«method.name»Element& data) override{
                    // nothing to do with methods on server side
                    std::cout << "Server «method.name» (empty for now)" << std::endl;
                }
            «ENDFOR»

        private:
            std::shared_ptr<«fInterface.getStubClassName»> m_transport;
        };

        class CClientVisitor : public IVisitor
        {
        public:
            CClientVisitor(std::shared_ptr<«fInterface.proxyClassName»<>> transport)
                : m_transport(transport) {}

            «FOR attribute : fInterface.attributes»
                «IF attribute.isObservable»
                    void visit_«attribute.name»(«attribute.name»Element&) {
                        // nothing to do with attributes on client side
                        std::cout << "Client «attribute.name» (empty for now)" << std::endl;
                    }
                «ENDIF»
            «ENDFOR»

            «FOR broadcast : fInterface.broadcasts»
                void visit_«broadcast.name»(«broadcast.name»Element& data) override
                {
                    // nothing to do with broadcasts on client side
                    std::cout << "Client «broadcast.name» (empty for now)" << std::endl;
                }
            «ENDFOR»

            «FOR method : fInterface.methods»
                virtual void visit_«method.name»(«method.name»Element& data) override;
            «ENDFOR»

        private:
            std::shared_ptr<«fInterface.proxyClassName»<>> m_transport;
        };

        class IElement
        {
            virtual void visit(IVisitor& visitor) = 0;
        };

        // classes for service's attributes
        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            struct «attribute.name»Element : public IElement
            {
                void visit(IVisitor& visitor) override {
                    visitor.visit_«attribute.name»(*this);
                }
                «attribute.getTypeName(fInterface, true)» m_data;
            }; // class «attribute.name»Element

            «ENDIF»
        «ENDFOR»
        // classes for service's broadcasts
        «FOR broadcast : fInterface.broadcasts»
            struct «broadcast.name»Element : public IElement
            {
                void visit(IVisitor& visitor) override {
                    visitor.visit_«broadcast.name»(*this);
                }

                «FOR argument : broadcast.outArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
            }; // class «broadcast.name»Element

        «ENDFOR»
        // classes for service's methods
        «FOR method : fInterface.methods»
            struct «method.name»Element : public IElement
            {
                void visit(IVisitor& visitor) override {
                    visitor.visit_«method.name»(*this);
                }

                «FOR argument : method.inArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
                «FOR argument : method.outArgs»
                    «argument.getTypeName(fInterface, true)» m_«argument.name»;
                «ENDFOR»
                «IF (method.hasError)»
                    «method.getErrorNameReference(method.eContainer)» m_error;
                «ENDIF»
            }; // class «method.name»Element

        «ENDFOR»

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            void CServerVisitor::visit_«attribute.name»(«attribute.name»Element& data) {
                m_transport->fire«attribute.className»Changed(data.m_data);
                std::cout << "Server «attribute.name»" << std::endl;
            }
            «ENDIF»
        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            void CServerVisitor::visit_«broadcast.name»(«broadcast.name»Element& data) {
                m_transport->fire«broadcast.name»Event(
                «var boolean first = true»
                «FOR argument : broadcast.outArgs»
                    «IF !first»,«ENDIF»«{first = false; ""}» data.m_«argument.name»
                «ENDFOR»
                );
                std::cout << "Server «broadcast.name»" << std::endl;
            }
        «ENDFOR»

        «FOR method : fInterface.methods»
            void CClientVisitor::visit_«method.name»(«method.name»Element& data) {
                CommonAPI::CallStatus _internalCallStatus;
                «IF method.hasError»
                    «method.getErrorNameReference(method.eContainer)» _error;
                «ENDIF»
                «method.generateClientMethodCall»;
                «IF method.hasError»
                    if (_error != data.m_error)
                    {
                        std::cout << "Warning : Server response does not match the stored value for «method.name»() call";
                    }
                «ENDIF»
                std::cout << "Client «method.name»" << std::endl;
            }
        «ENDFOR»

        #include "«fInterface.getDumpReaderHeaderPath»"

        class CDataProvider
        {
        public: // methods
            CDataProvider(const std::string& file_name)
                : m_reader(file_name)
                , m_curr_ts(std::numeric_limits<std::size_t>::max())
            {
                initReaders();
            }
            void provide(std::size_t ts_id, IVisitor& visitor)
            {
                if (ts_id >= m_reader.getTimestamps().size())
                {
                    throw std::runtime_error("Request data for non-existent timestamp id");
                }
                std::size_t prev_ts = m_curr_ts;
                m_curr_ts = ts_id;

                if (m_curr_ts != prev_ts + 1)
                {
                    for (auto record: m_reader.getGropedTimestamps())
                    {
                        providePastRecord(ts_id, record.second, visitor);
                    }
                }
                else
                {
                    provideRecord(ts_id, visitor);
                }
            }

            const std::vector<int64_t>& getTimestamps() {
                return m_reader.getTimestamps();
            }
        private: // fields

            JsonDumpReader m_reader;
            std::map<std::string, std::function<void(IVisitor&)>> m_readers;
            std::size_t m_curr_ts;
            «generateNativeInjection(fInterface.name + "_PLAYBACK_READER_PRIVATE_MEMBERS")»
        private: // methods
            void providePastRecord(std::size_t ts_id, const std::vector<std::size_t>& storage, IVisitor &visitor)
            {
                auto iter = std::upper_bound(storage.begin(), storage.end(), ts_id,
                    [this](std::size_t a, std::size_t b) -> bool
                    {
                        return m_reader.getTimestamps()[a] <
                               m_reader.getTimestamps()[b];
                    });

                if (iter == storage.begin())
                {
                    // no records before this time
                    return;
                }
                iter = std::prev(iter);
                provideRecord(*iter, visitor);
            }

            void provideRecord(std::size_t ts_id, IVisitor &visitor)
            {
                m_reader.jump(ts_id);

                auto func = m_readers.find(m_reader.getRecordName(ts_id));
                if (func != m_readers.end())
                {
                    func->second(visitor);
                }
                else
                {
                    std::cout << "WARNING: " << m_reader.getRecordName(ts_id)
                              << " will not processed" << std::endl;
                }
            }

            void initReaders()
            {
                «generateNativeInjection(fInterface.name + "_PLAYBACK_CONSTRUCTOR")»

                m_readers = {
                «FOR attribute : fInterface.attributes»
                    «IF attribute.isObservable»
                        {"«attribute.className»", [this](IVisitor& visitor)
                            {
                                «attribute.name»Element data_elem;
                                m_reader.readItem("«attribute.name»", data_elem.m_data);
                                «generateNativeInjection(fInterface.name + '_' + attribute.name + '_READ')»

                                visitor.visit_«attribute.name»(data_elem);
                            }
                        },
                    «ENDIF»
                «ENDFOR»
                «FOR broadcast : fInterface.broadcasts»
                    {"«broadcast.className»", [this](IVisitor& visitor)
                        {
                            «broadcast.name»Element data_elem;
                            «FOR argument : broadcast.outArgs»
                                m_reader.readItem("«argument.name»", data_elem.m_«argument.name»);
                                «generateNativeInjection(fInterface.name + '_' + argument.name + '_READ')»

                            «ENDFOR»
                            visitor.visit_«broadcast.name»(data_elem);
                        }
                    },
                «ENDFOR»
                «FOR method : fInterface.methods»
                    {"«method.name»", [this](IVisitor& visitor)
                        {
                            «method.name»Element data_elem;
                            «FOR argument : method.inArgs»
                                m_reader.readItem("«argument.name»", data_elem.m_«argument.name»);
                            «ENDFOR»
                            «FOR argument : method.outArgs»
                                m_reader.readItem("«argument.name»", data_elem.m_«argument.name»);
                            «ENDFOR»
                            «IF (method.hasError)»
                                m_reader.readItem("_error", data_elem.m_error);
                            «ENDIF»
                            «generateNativeInjection(fInterface.name + '_' + method.name + '_READ')»
                            visitor.visit_«method.name»(data_elem);
                            «generateNativeInjection(fInterface.name + '_' + method.name + '_AFTER_SEND')»
                        }
                    },
                «ENDFOR»
                };
            }
        };

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»

        #include <CommonAPI/CommonAPI.hpp>
        #include <timeService/CTimeClient.hpp>
        #include <«fInterface.stubDefaultHeaderPath»>

        int main(int argc, char** argv)
        {
            «fInterface.generateNamespaceUsage»

            // TODO: catch SIGINT

            if (argc < 3)
            {
                std::cout << "Format: filename serviceName [server/client(default: server)]\n";
                return 0;
            }

            bool is_server = argc > 3 && argv[3] == std::string("client") ? false : true;
            const std::string domain = "local";
            const std::string instance = argv[2];
            uint32_t retry_count = 5;

            std::shared_ptr<CommonAPI::Runtime> runtime = CommonAPI::Runtime::get();
            CDataProvider provider(argv[1]);
            IVisitor* visitor;

            if (is_server)
            {
                auto service = std::make_shared<«fInterface.stubDefaultClassName»>();
                runtime->registerService(domain, instance, service);
                std::cout << "Successfully Registered Service!" << std::endl;

                visitor = new CServerVisitor(service);
            }
            else
            {
                auto proxy = runtime->buildProxy<«fInterface.proxyClassName»>(domain.c_str(), instance.c_str());
                if (!proxy) {
                    throw std::runtime_error(instance + " : failed to create ");
                }

                while (retry_count && !proxy->isAvailable()) {
                    retry_count--;
                    std::cout << std::endl << instance << " : try co connect " << std::endl;
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                }

                if (!retry_count) {
                    throw std::runtime_error(instance + " : service is not available");
                }
                visitor = new CClientVisitor(proxy);
            }

            TimeService::CTimeClient time_client(provider.getTimestamps());
            while (1)
            {
                std::size_t idx = static_cast<std::size_t>(time_client.waitForNexTimestamp());
                provider.provide(idx, *visitor);
            }
            return 0;
        }

    '''
}
