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
        fileSystemAccess.generateFile('CMakeLists.txt', PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateCMakeLists(deploymentAccessor, modelid))
    }

    def private generateCMakeLists(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        set(DUMPER_APP_NAME _gen_«fInterface.name»_dumper)
        set(PLAYBACK_APP_NAME _gen_«fInterface.name»_playback)

        set(PLAYBACK_SOURCES
            «fInterface.playbackMainFile»
        )

        set(DUMPER_SOURCES
            «fInterface.dumperMainFile»
        )

        add_executable(${DUMPER_APP_NAME} ${DUMPER_SOURCES})

        target_link_libraries(${DUMPER_APP_NAME}
            PRIVATE json_serializer
            «generateNativeInjection(fInterface.name, 'DUMPER_LINK_LIBRARIES', '#')»
        )

        add_executable(${PLAYBACK_APP_NAME} ${PLAYBACK_SOURCES})

        target_link_libraries(${PLAYBACK_APP_NAME}
            PRIVATE json_serializer
            «generateNativeInjection(fInterface.name, 'PLAYBACK_LINK_LIBRARIES', '#')»
        )

        «generateNativeInjection(fInterface.name, 'CMAKE_END', '#')»
    '''
}
