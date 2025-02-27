usage()
{ echo "Usage: $0 [-p <profile>(Default="default") ] [-c <yes|no(default)>] [-t <type>] [-r <region>] [-x <yes|no(default)>]" 1>&2; exit 1;
}
x="no"
p="default" # profile
f="no"
v="no"
r="no" # region
c="no" # combine mode

while getopts ":p:r:x:f:v:t:i:c:" o; do
    case "${o}" in
    #    a)
    #        s=${OPTARG}
    #    ;;
        i)
            i=${OPTARG}
        ;;
        t)
            t=${OPTARG}
        ;;
        r)
            r=${OPTARG}
        ;;
        x)
            x="yes"
        ;;
        p)
            p=${OPTARG}
        ;;
        f)
            f="yes"
        ;;
        v)
            v="yes"
        ;;
        c)
            c="yes"
        ;;
        
        *)
            usage
        ;;
    esac
done
shift $((OPTIND-1))

export aws2tfmess="# File generated by aws2tf see https://github.com/aws-samples/aws2tf"

if [ -z ${AWS_ACCESS_KEY_ID+x} ] && [ -z ${AWS_SECRET_ACCESS_KEY+x} ];then
    mysub=`aws sts get-caller-identity --profile $p | jq .Account | tr -d '"'`
else
    mysub=`aws sts get-caller-identity | jq .Account | tr -d '"'`
fi
if [ "$r" = "no" ]; then
echo "Region not specified - Getting region from aws cli ="
r=`aws configure get region`
echo $r
fi
if [ "$mysub" == "null" ] || [ "$mysub" == "" ]; then
    echo "Account is null exiting"
    exit
fi



s=`echo $mysub`
mkdir -p  generated/tf.$mysub
cd generated/tf.$mysub


if [ "$f" = "no" ]; then
    if [ "$c" = "no" ]; then
        echo "Cleaning generated/tf.$mysub"
        rm -f *.txt *.sh *.log *.sav *.zip
        rm -f *.tf *.json *.tmp 
        rm -f terraform.* tfplan 
        rm -rf .terraform data aws_*
    fi
else
    sort -u data/processed.txt > data/pt.txt
    cp pt.txt data/processed.txt
fi

mkdir -p data

rm -f import.log
#if [ "$f" = "no" ]; then
#    ../../scripts/resources.sh 2>&1 | tee -a import.log
#fi

if [ ! -z ${AWS_DEFAULT_REGION+x} ];then
    r=`echo $AWS_DEFAULT_REGION`
    echo "region $AWS_DEFAULT_REGION set from env variables"
fi

if [ ! -z ${AWS_PROFILE+x} ];then
    p=`echo $AWS_PROFILE`
    echo "profile $AWS_PROFILE set from env variables"
fi

export AWS="aws --profile $p --region $r --output json "
echo " "
echo "Account ID = ${s}"
echo "AWS Resource Group Filter = ${g}"
echo "Region = ${r}"
echo "AWS Profile = ${p}"
echo "Extract KMS Secrets to .tf files (insecure) = ${x}"
echo "Fast Forward = ${f}"
echo "Verify only = ${v}"
echo "Type filter = ${t}"
echo "Combine = ${c}"
echo "AWS command = ${AWS}"
echo " "


# cleanup from any previous runs
#rm -f terraform*.backup
#rm -f terraform.tfstate
#rm -f tf*.sh


# write the aws.tf file
printf "terraform { \n" > aws.tf
printf "  required_providers {\n" >> aws.tf
printf "   aws = {\n" >> aws.tf
printf "     source  = \"hashicorp/aws\"\n" >> aws.tf
printf "      version = \"= 3.45.0\"\n" >> aws.tf
printf "    }\n" >> aws.tf
printf "  }\n" >> aws.tf
printf "}\n" >> aws.tf
printf "\n" >> aws.tf
printf "provider \"aws\" {\n" >> aws.tf
printf " region = \"%s\" \n" $r >> aws.tf
if [ -z ${AWS_ACCESS_KEY_ID+x} ] && [ -z ${AWS_SECRET_ACCESS_KEY+x} ];then
    printf " shared_credentials_file = \"~/.aws/credentials\" \n"  >> aws.tf
    printf " profile = \"%s\" \n" $p >> aws.tf
    export AWS="aws --profile $p --region $r --output json "
else
    export AWS="aws --region $r --output json "
fi
printf "}\n" >> aws.tf

cat aws.tf
#cp ../../stubs/*.tf .

if [ "$t" == "no" ]; then t="*"; fi

pre="*"
if [ "$t" == "vpc" ]; then
pre="1*"
t="*"
if [ "$i" == "no" ]; then
    echo "VPC Id null exiting - specify with -i <vpc-id>"
    exit
fi
fi

if [ "$t" == "tgw" ]; then
pre="type"
t="transitgw"
if [ "$i" == "no" ]; then
    echo "TGW Id null exiting - specify with -i <tgw-id>"
    exiting
fi
fi


if [ "$t" == "ecs" ]; then
pre="3*"
if [ "$i" == "no" ]; then
    echo "Cluster Name null exiting - specify with -i <cluster-name>"
    exit
fi
fi


if [ "$t" == "eks" ]; then
pre="30*"
if [ "$i" == "no" ]; then
    echo "Cluster Name null exiting - specify with -i <cluster-name>"
    exit
fi
fi

if [ "$t" == "org" ]; then pre="01*"; fi
if [ "$t" == "code" ]; then pre="62*"; fi
if [ "$t" == "appmesh" ]; then pre="360*"; fi
if [ "$t" == "kms" ]; then pre="08*"; fi
if [ "$t" == "lambda" ]; then pre="700*"; fi
if [ "$t" == "rds" ]; then pre="60*"; fi
if [ "$t" == "emr" ]; then pre="37*"; fi
if [ "$t" == "secrets" ]; then pre="45*"; fi
if [ "$t" == "lf" ]; then pre="63*"; fi
if [ "$t" == "athena" ]; then pre="66*"; fi
if [ "$t" == "glue" ]; then pre="65*"; fi

pwd
if [ "$c" == "no" ]; then
    echo "terraform init -upgrade"
    terraform init -upgrade -no-color 2>&1 | tee -a import.log
fi

exclude="iam"

if [ "$t" == "iam" ]; then pre="03*" && exclude="xxxxxxx"; fi
ls
#############################################################################
date
lc=0
echo "t=$t"
echo "loop through providers"
tstart=`date +%s`
for com in `ls ../../scripts/$pre-get-*$t*.sh | cut -d'/' -f4 | sort -g`; do    
    start=`date +%s`
    echo "$com" 
    if [[ "$com" == *"${exclude}"* ]]; then
        echo "skipping $com"
    else
        docomm=". ../../scripts/$com $i"
        if [ "$f" = "no" ]; then
            eval $docomm 2>&1 | tee -a import.log
        else
            grep "$docomm" data/processed.txt
            if [ $? -eq 0 ]; then
                echo "skipping $docomm"
            else
                eval $docomm 2>&1 | tee -a import.log
            fi
        fi
        lc=`expr $lc + 1`

        file="import.log"
        while IFS= read -r line
        do
            if [[ "${line}" == *"Error"* ]];then
          
                if [[ "${line}" == *"Duplicate"* ]];then
                    echo "Ignoring $line"
                else
                    echo "Found Error: $line exiting .... (pass for now)"
                    
                fi
            fi

        done <"$file"

        echo "$docomm" >> data/processed.txt
        terraform validate -no-color
        end=`date +%s`
        runtime=$((end-start))
        echo "$com runtime $runtime seconds"
    fi
    
done

#########################################################################
tend=`date +%s`
truntime=$((tend-tstart))
echo "Total runtime in seconds $truntime"

date

echo "terraform fmt > /dev/null ..."
terraform fmt > /dev/null
echo "Terraform validate ..."
terraform validate -no-color


if [ "$v" = "yes" ]; then
    exit
fi

echo "Terraform Refresh ..."
terraform refresh  -no-color
echo "Terraform Plan ..."
terraform plan -no-color

echo "---------------------------------------------------------------------------"
echo "aws2tf output files are in generated/tf.$mysub"
echo "---------------------------------------------------------------------------"

if [ "$t" == "eks" ]; then
echo "aws eks update-kubeconfig --name $i"
fi