#!/bin/bash
set -e

source $HOME/.profile

CURRENT=$(curl -s http://127.0.0.1:3030/status | jq -r .version.version)
LATEST=$(curl --silent "https://api.github.com/repos/nearprotocol/nearcore/releases" | grep -Po '"tag_name": "\K.*?(?=")' | grep beta | head -1)

echo " " >> $HOME/nearupdate.status
echo `date` >> $HOME/nearupdate.status

if [ -z "$CURRENT" ]; then
	echo "Could not query the local NEAR version!  Aborting..." >> $HOME/nearupdate.status
        echo " " >> $HOME/nearupdate.status
        else
     	if [ -z "$LATEST" ]; then
               	echo "Could not query the remote NEAR version!  Aborting..." >> $HOME/nearupdate.status
                echo " " >> $HOME/nearupdate.status
                else
             	echo "Local NEAR version is: $CURRENT" >> $HOME/nearupdate.status
                if [[ $CURRENT != *$LATEST* ]]; then
			echo "Remote NEAR version is: $LATEST" >> $HOME/nearupdate.status
                        echo "Triggering NEAR automated upgrade!" >> $HOME/nearupdate.status

                        #Update & Build
                        rustup update
                        npm upgrade -g near-shell
                        pip3 install --user --upgrade nearup
			cd $HOME
			rm -rf $HOME/nearcore.bak
			cp -R $HOME/nearcore $HOME/nearcore.bak
                        rm -rf $HOME/nearcore
                        git clone --depth 1 --branch ${LATEST} https://github.com/nearprotocol/nearcore
			cd $HOME/nearcore
			make release

                        #Test
                        #python3 ./scripts/parallel_run_tests.py
	                nearup stop
                        nearup run localnet --binary-path $HOME/nearcore/target/release/
                        echo "Testing NEAR Localnet" >> $HOME/nearupdate.status
                        sleep 5
                        for count in {0..3}
                        do
                          LOCAL=$(curl -s http://127.0.0.1:303"$count"/status | jq -r .version.version)
                          if [[ $CURRENT == *$LATEST* ]]
                          then
                            echo "NEAR Node $count Operational" >> $HOME/nearupdate.status
                          else
                            cd $HOME; mv $HOME/nearcore.bak $HOME/nearcore
                            echo "NEAR Node Upgrade Failed -- Test Failed: NEAR Node $count Not Operational" >> $HOME/nearupdate.status
                            cd $HOME; ./near.sh
                            exit 1
                          fi
                        done
		      echo "NEAR Localnet Test Complete!" >> $HOME/nearupdate.status
                      cd $HOME; ./near.sh
	        else
                echo "Remote NEAR version is: $LATEST" >> $HOME/nearupdate.status
                echo "Nothing to do!" >> $HOME/nearupdate.status
               fi
       fi

fi
