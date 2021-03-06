# Instahelper-infra

## Автоматизация инфраструктуры для сервиса Instahelper

### Пререквизиты
В качестве провайдеров используются __Amazon Web Services__ и __Cloudflare__. У вас должны быть зарегистрированы
аккаунты в данных системах и настроен __AWS CLI__, информация об этом может быть найдена в документации Amazon или
официальном репозитории: https://github.com/aws/aws-cli

Так же вы должны зарегистрировать свой домен у любого регистратора и передать его под управление cloudlfare
переназначив DNS сервера в личном кабинете вашего регистратора. 

Перед запуском требуется установить Terraform

### Для работы нужны следующие переменные
Cоздайте в папке проекта файл __instahelper.tfvars__ со следующим содержимым
```
domain = "<ВАШ ДОМЕН>"
cloudflare_zone_id = "<ZONE ID ИЗ ВАШЕГО АККАУНТА CLOUDFLARE>"
aws_zone = "<РЕГИОН В КОТОРОМ БУДЕТ РАЗВЕРНУТА ВАША ИНФРАСТРУКТУРА>" #например eu-west-1
cloudflare_api_token = "<ВАШ CLOUDFLARE ТОКЕН>"
email = "<ВАШ EMAIL НА КОТОРЫЙ ВЫ РЕГИСТРИРОВАЛИ АККАУНТ CLOUDLFARE>"
```
### В текущей версии используется Terraform Cloud для отслеживания состояния инфраструктуры
Для запуска нужен аккаунт terraform cloud и токен.
В файл `~/.terraformrc` поместите ваш токен согласно официальной документации
terraform remote. Или выполните следующий код
```bash
>
      echo "credentials "app.terraform.io" {
      token = \"ваш токен\"
      }" > ~/.terraformrc
```
## Запуск
1. Склонируйте репозиторий в любую папку на вашем компьютере использую команду `git clone`
2. В папке с репозиторием поочередно выполните команды:
   1. `terraform init`
   2. `terraform plan`
   3. `terraform apply`

#### Для уничтожения инфраструктуры используйте команду `terraform destroy`
#### Ссылка на проект для разворачивания сервиса https://github.com/NickGlebanov/instahelper-service