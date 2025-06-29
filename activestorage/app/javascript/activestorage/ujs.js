import { DirectUploadsController } from "./direct_uploads_controller"
import { findElement } from "./helpers"

const processingAttribute = "data-direct-uploads-processing"
const submitButtonsByForm = new WeakMap
let started = false

export function start() {
  if (!started) {
    started = true
    document.addEventListener("click", didClick, true)
    document.addEventListener("submit", didSubmitForm, true)
    document.addEventListener("ajax:before", didSubmitRemoteElement)
  }
}

function didClick(event) {
  //自己最近的button或者input
  const button = event.target.closest("button, input")
  if (button && button.type === "submit" && button.form) {
    //记录form对应的button
    submitButtonsByForm.set(button.form, button)
  }
}

function didSubmitForm(event) {
  handleFormSubmissionEvent(event)
}

function didSubmitRemoteElement(event) {
  if (event.target.tagName == "FORM") {
    handleFormSubmissionEvent(event)
  }
}

function handleFormSubmissionEvent(event) {
  const form = event.target
  //表单提交的瞬间，检查是否有正在进行的DirectUpload
  //有直接返回，不继续传播事件
  if (form.hasAttribute(processingAttribute)) {
    event.preventDefault()
    return
  }

  const controller = new DirectUploadsController(form)
  const { inputs } = controller

  if (inputs.length) {
    event.preventDefault()
    //设置正在上传
    form.setAttribute(processingAttribute, "")
    inputs.forEach(disable)
    controller.start(error => {
      //删除正在上传属性
      form.removeAttribute(processingAttribute)
      if (error) {
        //出现错误，则设置所有域都可更改
        inputs.forEach(enable)
      } else {
        //上传表单
        submitForm(form)
      }
    })
  }
}

function submitForm(form) {
  //得到提交类型的button
  let button = submitButtonsByForm.get(form) || findElement(form, "input[type=submit], button[type=submit]")

  if (button) {
    const { disabled } = button
    button.disabled = false
    button.focus()
    button.click()
    button.disabled = disabled
  } else {
    button = document.createElement("input")
    button.type = "submit"
    button.style.display = "none"
    form.appendChild(button)
    button.click()
    form.removeChild(button)
  }
  submitButtonsByForm.delete(form)
}

function disable(input) {
  input.disabled = true
}

function enable(input) {
  input.disabled = false
}
