#!/bin/bash
#!/bin/bash
#if [ "$1" != "" ]; then
#    cmd[0]="$AWS iam list-policies"
#else
    cmd[0]="$AWS iam list-policies --scope Local"
#fi

pref[0]="Policies"
tft[0]="aws_iam_policy"
getp=0
for c in `seq 0 0`; do
 
    cm=${cmd[$c]}
    ttft=${tft[(${c})]}
    #echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "You don't have access for this resource"
        exit
    fi
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].Arn" | tr -d '"'`
            ocname=`echo $cname`
            cname=`echo $cname | rev | cut -f1 -d'/' | rev `
            pname=`echo $awsout | jq -r ".${pref[(${c})]}[(${i})].PolicyName"`

            if [ "$1" != "" ]; then
              
                getp=0
                if [ $cname == $1 ]; then
                    getp=1
                fi
            else
                echo "not set"
                getp=1
            fi
            if [ "$getp" == "1" ]; then
                fn=`printf "%s__%s.tf" $ttft $cname`
                if [ -f "$fn" ] ; then
                    echo "$fn exists already skipping"
                    exit
                fi

                echo "$ttft $cname"
                printf "resource \"%s\" \"%s\" {" $ttft $cname > $ttft.$cname.tf
                printf "}" >> $ttft.$cname.tf
                terraform import $ttft.$cname $ocname | grep Import
                terraform state show $ttft.$cname > t2.txt
                rm $ttft.$cname.tf
                cat t2.txt | perl -pe 's/\x1b.*?[mGKH]//g' > t1.txt
                #	for k in `cat t1.txt`; do
                #		echo $k
                #	done
                file="t1.txt"
                #fn=`printf "%s__%s.tf" $ttft $cname`
                #if [ -f "$fn" ] ; then
                #    echo "$fn exists already skipping"
                #    exit
                #fi
                echo $aws2tfmess > $fn
                while IFS= read line
                do
                    skip=0
                    # display $line or do something with $line
                    t1=`echo "$line"`
                    if [[ ${t1} == *"="* ]];then
                        tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '`
                        tt2=`echo "$line" | cut -f2- -d'='`
                        if [[ ${tt1} == *":"* ]];then
                            t1=`printf "\"%s\"=%s" $tt1 "$tt2"`
                        fi
                        if [[ ${tt1} == "arn" ]];then skip=1; fi
                        if [[ ${tt1} == "id" ]];then skip=1; fi
                        if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                        if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                        if [[ ${tt1} == "association_id" ]];then skip=1;fi
                        if [[ ${tt1} == "unique_id" ]];then skip=1;fi
                        if [[ ${tt1} == "create_date" ]];then skip=1;fi
                        #if [[ ${tt1} == "public_ip" ]];then skip=1;fi
                        if [[ ${tt1} == "private_ip" ]];then skip=1;fi
                        if [[ ${tt1} == "accept_status" ]];then skip=1;fi
                        #if [[ ${tt1} == "default_network_acl_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "ipv6_association_id" ]];then skip=1;fi
                        #if [[ ${tt1} == "ipv6_cidr_block" ]];then skip=1;fi
                    fi
                    if [ "$skip" == "0" ]; then
                        #echo $skip $t1
                        echo "$t1" >> $fn
                    fi
                    
                done <"$file"   # done while
            fi
        done # done for i
    fi
done


rm -f t*.txt

