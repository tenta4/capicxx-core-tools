package org.genivi.commonapi.core.generator

import org.franca.core.franca.FMethod

import javax.inject.Inject
import java.util.HashSet

import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor
import org.genivi.commonapi.core.preferences.PreferenceConstants

class FInterfacePlaybackGeneratorExtension {
    @Inject private extension FTypeGenerator
    @Inject private extension FrancaGeneratorExtensions
    @Inject private extension FNativeInjections
    @Inject private extension FXmlDumpReader

    def generatePlayback(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid) {

        fInterface.fillInjections()
        fileSystemAccess.generateFile(fInterface.dumpReaderHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateDumpReader(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.dataProviderHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateDataProvider(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.playbackMainPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generatePlaybackMain(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.getIVisitorHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateIVisitor(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.serverVisitorHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateServerVisitor(deploymentAccessor, modelid))
        fileSystemAccess.generateFile(fInterface.clientVisitorHeaderPath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateClientVisitor(deploymentAccessor, modelid))
    }

    def private generateClientMethodCall(FMethod fMethod)
    {
        var signature = fMethod.inArgs.map['data.m_data.m_' + elementName].join(', ')
        if (!fMethod.inArgs.empty)
            signature = signature + ', '

        signature = signature + '_internalCallStatus'

        if (fMethod.hasError)
            signature = signature + ', _error'

        if (!fMethod.outArgs.empty)
            signature = signature + ', ' + fMethod.outArgs.map['data.m_data.m_' + elementName].join(', ')

        //if (!fMethod.fireAndForget) {
        //    signature += ", &_info"
        //}
        return 'm_transport->' + fMethod.name + '(' + signature + ')'
    }

    def private defineVisitorElement(String name) '''
        struct «name»Element : public IElement
        {
            void visit(IVisitor& visitor) override {
                visitor.visit_«name»(*this);
            }
            «name»DumpType m_data;
        }; // class «name»Element
    '''

    def private generateIVisitor(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once

        #include <«fInterface.serrializationHeaderPath»>

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

        class IElement
        {
            virtual void visit(IVisitor& visitor) = 0;
        };

        // classes for service's attributes
        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            «defineVisitorElement(attribute.name)»

            «ENDIF»
        «ENDFOR»
        // classes for service's broadcasts
        «FOR broadcast : fInterface.broadcasts»
            «defineVisitorElement(broadcast.name)»

        «ENDFOR»
        // classes for service's methods
        «FOR method : fInterface.methods»
            «defineVisitorElement(method.name)»

        «ENDFOR»

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»

    '''

    def private generateServerVisitor(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once

        #include <«fInterface.stubDefaultHeaderPath»>

        #include "«fInterface.getIVisitorFile»"

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

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

        «FOR attribute : fInterface.attributes»
            «IF attribute.isObservable»
            void CServerVisitor::visit_«attribute.name»(«attribute.name»Element& data) {
                m_transport->fire«attribute.className»Changed(data.m_data.m_data);
                std::cout << "Server «attribute.name»" << std::endl;
            }
            «ENDIF»
        «ENDFOR»

        «FOR broadcast : fInterface.broadcasts»
            void CServerVisitor::visit_«broadcast.name»(«broadcast.name»Element& data) {
                «IF broadcast.selective»
                    m_transport->«broadcast.stubAdapterClassFireSelectiveMethodName»(
                «ELSE»
                    m_transport->«broadcast.stubAdapterClassFireEventMethodName»(
                «ENDIF»
                «var boolean first = true»
                «FOR argument : broadcast.outArgs»
                    «IF !first»,«ENDIF»«{first = false; ""}» data.m_data.m_«argument.name»
                «ENDFOR»
                );
                std::cout << "Server «broadcast.name»" << std::endl;
            }
        «ENDFOR»

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»
    '''

    def private generateClientVisitor(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #pragma once

        #include <«fInterface.proxyHeaderPath»>

        #include "«fInterface.getIVisitorFile»"

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

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

        «FOR method : fInterface.methods»
            void CClientVisitor::visit_«method.name»(«method.name»Element& data) {
                CommonAPI::CallStatus _internalCallStatus;
                «IF method.hasError»
                    «method.getErrorNameReference(method.eContainer)» _error;
                «ENDIF»
                «method.generateClientMethodCall»;
                «IF method.hasError»
                    if (_error != data.m_data.m_error)
                    {
                        std::cout << "Warning : Server response does not match the stored value for «method.name»() call";
                    }
                «ENDIF»
                std::cout << "Client «method.name»" << std::endl;
            }
        «ENDFOR»

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»

    '''

    def private generateDataProvider(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        #include <functional>

        «generateNativeInjection(fInterface.name, 'PLAYBACK_INCLUDES', '//')»

        #include "«fInterface.getIVisitorFile»"
        #include "«fInterface.getDumpReaderHeaderFile»"

        «fInterface.generateVersionNamespaceBegin»
        «fInterface.model.generateNamespaceBeginDeclaration»

        class CDataProvider
        {
        public: // methods
            CDataProvider(const std::string& file_name)
                : m_reader(file_name)
                , m_curr_ts(std::numeric_limits<std::size_t>::max())
            {
                «generateNativeInjection(fInterface.name, 'PLAYBACK_READER_CONSTRUCTOR', '//')»
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

            XmlDumpReader m_reader;
            std::map<std::string, std::function<void(std::size_t ts_id, IVisitor&)>> m_readers;
            std::size_t m_curr_ts;
            «generateNativeInjection(fInterface.name, 'PLAYBACK_READER_PRIVATE_MEMBERS', '//')»
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
                auto func = m_readers.find(m_reader.getRecordName(ts_id));
                if (func != m_readers.end())
                {
                    func->second(ts_id, visitor);
                }
                else
                {
                    std::cout << "WARNING: " << m_reader.getRecordName(ts_id)
                              << " will not processed" << std::endl;
                }
            }

            void initReaders()
            {
                m_readers = {
                «FOR attribute : fInterface.attributes»
                    «IF attribute.isObservable»
                        {"«attribute.className»", [this](std::size_t ts_id, IVisitor& visitor)
                            {
                                «attribute.name»Element data_elem;
                                m_reader.read(ts_id, data_elem.m_data);
                                «generateNativeInjection(fInterface.name + '_' + attribute.name, 'READ', '//')»

                                visitor.visit_«attribute.name»(data_elem);
                            }
                        },
                    «ENDIF»
                «ENDFOR»
                «FOR broadcast : fInterface.broadcasts»
                    {"«broadcast.className»", [this](std::size_t ts_id, IVisitor& visitor)
                        {
                            «broadcast.name»Element data_elem;
                            m_reader.read(ts_id, data_elem.m_data);

                            «generateNativeInjection(fInterface.name + '_' + broadcast.name, 'READ', '//')»

                            visitor.visit_«broadcast.name»(data_elem);
                        }
                    },
                «ENDFOR»
                «FOR method : fInterface.methods»
                    {"«method.name»", [this](std::size_t ts_id, IVisitor& visitor)
                        {
                            «method.name»Element data_elem;
                            m_reader.read(ts_id, data_elem.m_data);

                            «generateNativeInjection(fInterface.name + '_' + method.name, 'READ', '//')»

                            visitor.visit_«method.name»(data_elem);

                            «generateNativeInjection(fInterface.name + '_' + method.name, 'AFTER_SEND', '//')»
                        }
                    },
                «ENDFOR»
                };
            }
        };

        «fInterface.model.generateNamespaceEndDeclaration»
        «fInterface.generateVersionNamespaceEnd»

    '''

    def private generatePlaybackMain(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''

        #include <boost/program_options.hpp>
        #include <CommonAPI/CommonAPI.hpp>
        #include <timeService/CTimeClient.hpp>

        #include "«fInterface.dataProviderHeaderFile»"
        #include "«fInterface.serverVisitorFile»"
        #include "«fInterface.clientVisitorFile»"

        class TimeProvider
        {
        public:
            TimeProvider(const std::vector<int64_t>& timestamps, bool is_sys_time = true)
                : m_timestamps(timestamps)
                , m_current_ts(m_timestamps.size())
                , m_time_client(TimeService::CTimeClient(timestamps))
            {
                m_wait_function = is_sys_time ?
                    std::function<std::size_t()>([this]() {
                        if (++m_current_ts >= m_timestamps.size()) {
                            m_current_ts = 0;
                            m_delta_time = getSystemTimestamp() - m_timestamps.front();
                        }

                        int64_t sleep_time = m_timestamps.at(m_current_ts) +
                            m_delta_time - getSystemTimestamp();

                        std::this_thread::sleep_for(std::chrono::microseconds(sleep_time));
                        return m_current_ts;
                    }) :
                    std::function<std::size_t()>([this]() {
                        int64_t res = -1;
                        while ((res = m_time_client.waitForNexTimestamp()) < 0);
                        return static_cast<std::size_t>(res);
                    });
            }

            std::size_t waitForNexTimestamp() {
                return m_wait_function();
            }

            static int64_t getSystemTimestamp() {
                return std::chrono::duration_cast<std::chrono::microseconds>(
                    std::chrono::system_clock::now().time_since_epoch()).count();
            }

        private:
            std::vector<int64_t> m_timestamps;
            std::function<std::size_t()> m_wait_function;

            std::size_t m_current_ts;
            int64_t m_delta_time;

            TimeService::CTimeClient m_time_client;
        };

        int main(int argc, char** argv)
        {
            namespace po = boost::program_options;
            «fInterface.generateNamespaceUsage»

            std::string dump_filename = "«fInterface.name»_dump.xml";

            const std::string domain = "local";
            std::string service_name;

            bool client_mode = false;
            bool system_mode = false;

            po::options_description desc("Allowed options");
            desc.add_options()
                    ("help,h", "print usage message")
                    ("dump_file,d", po::value<std::string>(&dump_filename)->default_value(dump_filename), "full pathname for dump file")
                    ("service_name,s", po::value<std::string>(&service_name)->required(), "connection instance name")
                    ("client_mode,c", po::value<bool>(&client_mode)->default_value(client_mode), "work in client mode; by default app plays only server events")
                    ("system_time,t", po::value<bool>(&system_mode)->default_value(system_mode), "work without TimeService synchronization");


            try {
                po::variables_map vm;
                po::store(po::parse_command_line(argc, argv, desc), vm);
                if (vm.count("help")) {
                    std::cout << desc << std::endl;
                    return 0;
                }
                po::notify(vm);
            } catch(std::exception& e) {
                std::cerr << e.what() << std::endl;
                std::cerr << desc << std::endl;
                return 0;
            }

            std::shared_ptr<CommonAPI::Runtime> runtime = CommonAPI::Runtime::get();
            CDataProvider provider(dump_filename);
            IVisitor* visitor;

            if (!client_mode)
            {
                auto service = std::make_shared<«fInterface.stubDefaultClassName»>();
                runtime->registerService(domain, service_name, service);
                std::cout << "Successfully Registered Service!" << std::endl;

                visitor = new CServerVisitor(service);
            }
            else
            {
                auto proxy = runtime->buildProxy<«fInterface.proxyClassName»>(domain.c_str(), service_name.c_str());
                if (!proxy) {
                    throw std::runtime_error(service_name + " : failed to create ");
                }

                while (!proxy->isAvailable()) {
                    std::cout << std::endl << service_name << " : try co connect " << std::endl;
                    std::this_thread::sleep_for(std::chrono::seconds(1));
                }

                visitor = new CClientVisitor(proxy);
            }

            TimeProvider time_provider(provider.getTimestamps(), system_mode);
            while (1)
            {
                std::size_t idx = time_provider.waitForNexTimestamp();
                provider.provide(idx, *visitor);
            }
            return 0;
        }
    '''
}
