package water.gradle.plugins
import org.gradle.api.*
import org.gradle.api.plugins.*
import groovy.xml.MarkupBuilder
import java.util.regex.Matcher

apply plugin: 'convertR2html'
apply plugin: 'manageLocalClouds'
apply plugin: 'testThatRunner'

buildscript {
    repositories {
        mavenCentral()
        jcenter()
    }

    dependencies {
        compile gradleApi()
        compile localGroovy()
    }
}

class rTestThatRunner implements Plugin<Project> {
    def eol = System.getProperty('line.separator')
    def fs  = System.getProperty('file.separator')

    void apply(Project project) {
        project.task( 'testThatRunner', dependsOn: project.getTasksByName('manageLocalClouds',true).first() ) << {
        def folders = ["${project.projectDir}/src/test/R"]
        def testMarker = ~/test.+\.[rR]/

        def getTests = {
            def what = new File(it).list([accept:{d, f-> f ==~ testMarker }] as FilenameFilter)
            (what == null)?[]:what.toList()
        }

        def pickActions = {from->
            def answer = []
            from.each{
                getTests(it).each{item->
                    project.logger.info "Found test ${item} in folder ${it}"
                    answer.add(new Tuple<String,String>(it, item))
                }
            }
            answer
        }

        def readIpAndPort = {
            new Tuple(project.ext.ip, project.ext.port)
        }

        def pattern = ~/h2o.+\.gz/
        def artifact = new File([project.projectDir, "R/src/contrib"].join(fs))
                .list([accept:{d, f-> f ==~ pattern }] as FilenameFilter)[0]
        def gz = [project.projectDir, "R/src/contrib", artifact].join(fs)

        project.ant.exec(dir: project.projectDir, executable: 'R', ){
            arg(line: "--quiet CMD INSTALL ${gz}")
        }

        pickActions(folders).each{ tuple->

        def t = readIpAndPort()

        def cmd = "--quiet CMD BATCH --slave " + tuple.get(1)

        project.ant.exec(dir: tuple.get(0), executable: 'R', ){
            env(key: "H2O_IP", value: t.get(0))
            env(key: "H2O_PORT", value: t.get(1))
            arg(line: cmd)
        }
       }
      }
    }
}
