class oracleSites {

file { 'rc.local':
	ensure => 'present',
	owner => 'root',
	group => 'root',
	mode => '755',
	source => [
		"/vagrant/rc.local"
	],
	path => '/etc/rc.d/rc.local',
}

# copy listener.ora
file { 'listener.ora':
	ensure => 'present',
        owner => $owner,
        group => $group,
        mode => $mode,
        source => [
                "/vagrant/listener.ora"
        ],
        path => '/u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora',
	notify => Exec['oracleXE'],
}

# restart OracleXE
exec { 'oracleXE':
	before => Exec['oracle-script'],
        command => 'sudo /etc/init.d/oracle-xe restart',
        refreshonly => 'true',
}

# Creating Sites directory
$varSitesDirectory = [ '/opt/sites', '/var/run/sites', '/var/log/sites' ]
file { $varSitesDirectory:
  	owner => $owner,
  	group => $group,
  	mode => $mode,
        ensure => 'directory',
	notify => Exec['makeSitesDirectory'],
}

# Clone /vagrant/ /opt/sites/
exec { 'makeSitesDirectory':
        require => Package[$packages],
        command => 'sudo -u vagrant -i git clone /vagrant/ /opt/sites',
        refreshonly => 'true',
}

# Unzip WCS_Sites.zip in /opt/sites/
exec { 'unzipSites':
        require => Exec['makeSitesDirectory'],
        command => 'sudo -u vagrant -i unzip -q /tmp/WCS_Sites.zip -d /opt/sites',
        creates => '/opt/sites/Sites',
}

# Copy ojdbc6.jar
file { 'ojdbc6.jar':
        owner => $owner,
        group => $group,
        mode => $mode,
        source => [
                "/u01/app/oracle/product/11.2.0/xe/jdbc/lib/ojdbc6.jar"
        ],
        path => '/opt/sites/bin/ojdbc6.jar',
        require => Exec['unzipSites'],
	notify => Exec['oracle-script'],
        ensure => 'present',
        replace => 'false',
}

# Creating Database Schema
exec { 'oracle-script':
        before => Exec['installSites'],
    	command => 'sudo -u vagrant -i sqlplus sys/sa as sysdba@localhost/XE @/vagrant/oracleCreateUser.sql',
    	onlyif => 'test -f /vagrant/oracleCreateUser.sql',
	refreshonly => 'true',
}

# Installing Sites
exec { 'installSites':
        before => Exec['agileSitesPatch'],
    	command => 'sudo -u vagrant -i bash /opt/sites/setup.sh 8181 ORACLE',
        creates => '/opt/sites/home/sites.done',
}

# Sites.done if it has been installed
file { 'sites.done':
        owner => $owner,
        group => $group,
        mode => $mode,
        path => '/opt/sites/home/sites.done',
        require => Exec['installSites'],
        ensure => 'present',
        replace => 'false',
        content => 'Sites has been installed',
}

# Installing Patch6
exec { 'agileSitesPatch':
        before => File['patch.done'],
	command => 'sudo -u vagrant -i bash /opt/sites/agileSitesPatch.sh',
	creates => '/opt/sites/patch6/patch.done',
	onlyif => [  
        	'grep -c "Installation Finished Successfully" /opt/sites/Sites/log.out',
        ],
}

# Patch.done if it has been applied
file { 'patch.done':
        owner => $owner,
        group => $group,
        mode => $mode, 
	path => '/opt/sites/patch6/patch.done',
        ensure => 'present',
	replace => 'false',
	content => 'Patch6 has been applied',
}  

}
