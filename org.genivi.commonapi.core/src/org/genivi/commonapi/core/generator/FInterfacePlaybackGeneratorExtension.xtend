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

    def generatePlayback(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid) {

        fileSystemAccess.generateFile(fInterface.playbackSourcePath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.extGeneratePlayback(deploymentAccessor, modelid))
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
            signature = signature + ', ' + fMethod.outArgs.map[elementName].join(', ')

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

        #include "preprocessor/AdaptNamedAttrsAdt.hpp"
        #include "json_serializer/JsonSerializer.hpp"
        #include <«fInterface.serrializationHeaderPath»>
        #include <«fInterface.stubHeaderPath»>
        #include <«fInterface.proxyHeaderPath»>

        // TODO: move to CDataProvider
        «generateNativeInjection(fInterface.name + "PlaybackIncludes")»

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
            «generateNativeInjection(fInterface.name + "ClientPlaybackPrivateMembers")»
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
                «generateNativeInjection(fInterface.name + "_" + method.name + "_begin_ClientPlayback")»
                CommonAPI::CallStatus _internalCallStatus;
                «IF method.hasError»
                    «method.getErrorNameReference(method.eContainer)» _error;
                «ENDIF»
                «FOR argument : method.outArgs»
                     «argument.getTypeName(method, true)» «argument.elementName»;
                «ENDFOR»
                «method.generateClientMethodCall»;
                «IF method.hasError»
                    if (_error != data.m_error)
                    {
                        throw std::runtime_error("Server response does not match the stored value for «method.name»() call");
                    }
                «ENDIF»
                «generateNativeInjection(fInterface.name + "_" + method.name + "_end_ClientPlayback")»
                std::cout << "Client «method.name»" << std::endl;
            }
        «ENDFOR»

        struct SCall
        {
            std::string m_name;
            std::fstream::pos_type m_pos;
        };

        static const std::string s_time_key = "\"time\"";
        static const std::string s_name_key = "\"name\"";

        class JsonDumpReader
        {
        public:
            JsonDumpReader(const std::string& file_name);
            const std::vector<int64_t>& getTimestamps() const;
            const std::map<std::string, std::vector<std::size_t>>& getGropedTimestamps() const;

            void jump(std::size_t ts_id);
            const std::string& getRecordName(std::size_t ts_id);

            template<class T>
            void readItem(const std::string& tag, T& res);

        private:
            bool readKey(const std::string& src, const std::string& key, std::string& val);
            bool findBracket(const std::string& src, bool is_begin);

            std::ifstream m_file;

            std::vector<SCall> m_calls;
            std::vector<int64_t> m_timestamps;
            std::map<std::string, std::vector<std::size_t>> m_grouped_timestamps;

            std::map<std::string, std::function<void(IVisitor&, boost::property_tree::ptree pt)>> m_functions;
            boost::property_tree::ptree m_curr_pt;
        };

        template<class T>
        void JsonDumpReader::readItem(const std::string& tag, T& res) {
            boost::property_tree::ptree tmp_pt = m_curr_pt.get_child(tag);
            JsonSerializer::readFromPtree(tmp_pt, res);
        }

        const std::string& JsonDumpReader::getRecordName(std::size_t ts_id) {
            return m_calls.at(ts_id).m_name;
        }

        const std::vector<int64_t>& JsonDumpReader::getTimestamps() const {
            return m_timestamps;
        }

        const std::map<std::string, std::vector<std::size_t>>& JsonDumpReader::getGropedTimestamps() const {
            return m_grouped_timestamps;
        }

        bool JsonDumpReader::findBracket(const std::string& src, bool is_begin) {
            const std::string to_find = is_begin ? "{" : "}";
            return src.find(to_find) != std::string::npos;
        }

        JsonDumpReader::JsonDumpReader(const std::string &file_name)
        {
            m_file.open(file_name.c_str());

            if (!m_file.is_open())
            {
                throw std::runtime_error("failed to open file '" + file_name + "'");
            }

            // TODO : check version

            std::string line;
            while (std::getline(m_file, line))
            {
                std::string time_val;
                if (readKey(line, s_time_key, time_val))
                {
                    m_timestamps.push_back(std::atoll(time_val.c_str()));

                    std::getline(m_file, line);
                    std::string name_val;
                    if (!readKey(line, s_name_key, name_val))
                    {
                        throw std::runtime_error("something wrong with file structure");
                    }

                    // skip comma separator
                    std::getline(m_file, line);

                    // skip "params" keyword
                    std::getline(m_file, line);

                    m_grouped_timestamps[name_val].push_back(m_calls.size());

                    std::fstream::pos_type back_offset = 2;
                    back_offset = (line.find('{') == std::string::npos) ? std::fstream::pos_type(3)
                                                                        : back_offset;
                    // return to "{" symbol
                    m_calls.push_back({name_val, m_file.tellg() - back_offset});
                }
            }

            m_file.close();
            m_file.open(file_name.c_str());
        }

        void JsonDumpReader::jump(std::size_t ts_id)
        {
            SCall call = m_calls[ts_id];
            m_file.seekg(call.m_pos);

            std::string line;
            std::stringstream ss;
            int brackets = 0;
            do
            {
                std::getline(m_file, line);
                brackets += findBracket(line, true);
                brackets -= findBracket(line, false);
                ss << line << std::endl;
            }
            while (brackets);

            boost::property_tree::read_json(ss, m_curr_pt);
        }

        bool JsonDumpReader::readKey(const std::string& src, const std::string& key, std::string& val)
        {
            const std::size_t key_len = key.length();
            const std::size_t key_begin_pos = src.find(key.c_str(), key_len);
            if (key_begin_pos == std::string::npos)
            {
                return false;
            }

            const std::size_t key_end_pos = key_begin_pos + key_len;
            const std::size_t val_begin_pos = src.find("\"", key_end_pos) + 1;
            const std::size_t val_end_pos = src.find("\"", val_begin_pos);
            val = src.substr(val_begin_pos, val_end_pos - val_begin_pos);
            return true;
        }

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
                «generateNativeInjection(fInterface.name + "PlaybackCtor")»

                m_readers = {
                «FOR attribute : fInterface.attributes»
                    «IF attribute.isObservable»
                        {"«attribute.className»", [this](IVisitor& visitor)
                            {
                                «attribute.name»Element data_elem;
                                m_reader.readItem("«attribute.name»", data_elem.m_data);
                                «generateNativeInjection("READ_" + fInterface.name + attribute.name)»

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
                                «generateNativeInjection("READ_" + fInterface.name + argument.name)»

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
                                «generateNativeInjection("READ_" + fInterface.name + argument.name)»

                            «ENDFOR»
                            «FOR argument : method.outArgs»
                                m_reader.readItem("«argument.name»", data_elem.m_«argument.name»);
                                «generateNativeInjection("READ_" + fInterface.name + argument.name)»

                            «ENDFOR»
                            «IF (method.hasError)»
                                m_reader.readItem("_error", data_elem.m_error);
                            «ENDIF»
                            visitor.visit_«method.name»(data_elem);
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
