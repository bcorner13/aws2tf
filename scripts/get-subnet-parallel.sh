#!/bin/bash
if [ "$1" != "" ]; then
    if [[ "$1" == "vpc-"* ]]; then
        cmd[0]="$AWS ec2 describe-subnets --filters \"Name=vpc-id,Values=$1\"" 
    else
        cmd[0]="$AWS ec2 describe-subnets --subnet-ids $1"
    fi
else
    cmd[0]="$AWS ec2 describe-subnets"
fi

pref[0]="Subnets"
tft[0]="aws_subnet"
idfilt[0]="SubnetId"

#rm -f ${tft[0]}.tf

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
            cname=$(echo $awsout | jq -r ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}")
            rname=${cname//:/_} && rname=${rname//./_} && rname=${rname//\//_}
            echo "$ttft $cname"
            fn=`printf "%s__%s.tf" $ttft $rname`
            if [ -f "$fn" ] ; then echo "$fn exists already skipping" && continue; fi
            #echo "calling import sub"
            . ../../scripts/parallel_import.sh $ttft $cname &
        done
        jc=`jobs -r | wc -l`
        echo "waiting on $jc imports"
        wait
        echo "finished import subs"
        # tf files
        for i in `seq 0 $count`; do
            #echo $i
            cname=$(echo $awsout | jq -r ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}")
            rname=${cname//:/_} && rname=${rname//./_} && rname=${rname//\//_}
            echo "$ttft $cname"
            fn=`printf "%s__%s.tf" $ttft $rname`
            if [ -f "$fn" ] ; then echo "$fn exists already skipping" && continue; fi

            file=`printf "%s-%s-1.txt" $ttft $rname`
            echo $aws2tfmess > $fn
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == "arn" ]];then skip=1; fi                
                    if [[ ${tt1} == "id" ]];then skip=1; fi          
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "ipv6_cidr_block_association_id" ]];then skip=1;fi
                    #if [[ ${tt1} == "availability_zone" ]];then skip=1;fi
                    if [[ ${tt1} == "availability_zone_id" ]];then skip=1;fi
                    if [[ ${tt1} == "vpc_id" ]]; then
                        vpcid=`echo $tt2 | tr -d '"'`
                        t1=`printf "%s = aws_vpc.%s.id" $tt1 $vpcid`
                    fi
                # else
                    #
                fi
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"

            if [ "$vpcid" != "" ]; then
                ../../scripts/100-get-vpc.sh $vpcid
            fi


            dfn=`printf "data/data_%s__%s.tf" $ttft $rname`
            printf "data \"%s\" \"%s\" {\n" $ttft $rname > $dfn
            printf "id = \"%s\"\n" "$cname" >> $dfn
            printf "}\n" >> $dfn


            
        done

    fi
done

pwd
rm -f *.backup 
rm -f *-1.txt

