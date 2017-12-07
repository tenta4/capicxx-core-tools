package org.genivi.commonapi.core.generator

import javax.inject.Inject
import org.eclipse.core.resources.IResource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.core.franca.FInterface
import org.genivi.commonapi.core.deployment.PropertyAccessor
import org.genivi.commonapi.core.preferences.PreferenceConstants
import org.genivi.commonapi.core.preferences.FPreferences

class FCMakeDumperPlaybackGenerator {
    @Inject private extension FrancaGeneratorExtensions

    def generateCMakeDumperPlayback(FInterface fInterface, IFileSystemAccess fileSystemAccess, PropertyAccessor deploymentAccessor, IResource modelid)
    {
        fileSystemAccess.generateFile('CMakeLists.txt', PreferenceConstants.P_OUTPUT_SKELETON, fInterface.generateCMakeLists(deploymentAccessor, modelid))
    }

    def private generateCMakeLists(FInterface fInterface, PropertyAccessor deploymentAccessor, IResource modelid) '''
        set(DUMPER_APP_NAME _gen_«fInterface.name»_dumper)
        set(PLAYBACK_APP_NAME _gen_«fInterface.name»_playback)

        set(DUMPER_SOURCES
            «fInterface.getPlaybackMainFile»
        )
    '''
}
