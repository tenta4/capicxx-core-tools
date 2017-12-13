package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor
import org.genivi.commonapi.core.preferences.PreferenceConstants
import org.genivi.commonapi.core.preferences.FPreferences

class FCMakeDumperPlaybackGenerator {
    @Inject private extension FNativeInjections
    @Inject private extension FrancaGeneratorExtensions

    def generateCMakeDumperPlayback(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid)
    {
        fInterface.fillInjections()
        fileSystemAccess.generateFile(fInterface.getCMakePath, PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateCMakeLists(deploymentAccessor, modelid))
    }

    def private generateCMakeLists(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        if(NOT DEFINED MODULE_NAME)
            message(ERROR "Plase set up MODULE_NAME variable before Dumper-Playback build")
            exit()
        endif()

        «IF optionValue(fInterface.name, 'OPTION_DUMPER_ENABLE') != 'false'»
            set(DUMPER_APP_NAME _gen_«fInterface.name»_dumper)
            set(DUMPER_SOURCES
                «fInterface.dumperMainFile»
            )

            add_executable(${DUMPER_APP_NAME} ${DUMPER_SOURCES})

            target_link_libraries(${DUMPER_APP_NAME}
                PRIVATE json_serializer
                «generateNativeInjection(fInterface.name, 'DUMPER_LINK_LIBRARIES', '#')»
            )

            use_ipc_api(${DUMPER_APP_NAME} ${MODULE_NAME})

        «ELSE»
            ###################
            # Dumper disabled #
            ###################
        «ENDIF»

        «IF optionValue(fInterface.name, 'OPTION_PLAYBACK_ENABLE') != 'false'»
            set(PLAYBACK_APP_NAME _gen_«fInterface.name»_playback)
            set(PLAYBACK_SOURCES
                «fInterface.playbackMainFile»
            )

            add_executable(${PLAYBACK_APP_NAME} ${PLAYBACK_SOURCES})

            target_link_libraries(${PLAYBACK_APP_NAME}
                PRIVATE json_serializer
                PRIVATE timeClient
                «generateNativeInjection(fInterface.name, 'PLAYBACK_LINK_LIBRARIES', '#')»
            )
            use_ipc_api(${PLAYBACK_APP_NAME} ${MODULE_NAME})
        «ELSE»
            ####################
            # Playbak disabled #
            ####################
        «ENDIF»

        «generateNativeInjection(fInterface.name, 'CMAKE_END', '#')»
    '''
}
