#include <cstdint>
#include <sweeteditor/c_api.h>
#include <sweeteditor/macro.h>

using NS_SWEETEDITOR::SharedPtr;

template<typename T>
class CPtrHolder {
public:
  explicit CPtrHolder(const SharedPtr<T>& ptr): m_ptr_(ptr) {
  }

  SharedPtr<T>& get() {
    return m_ptr_;
  }
private:
  SharedPtr<T> m_ptr_;
};

template<typename T, typename... Args>
intptr_t makeCPtrHolderToIntPtr(Args&&... args) {
  SharedPtr<T> ptr = std::make_shared<T>(std::forward<Args>(args)...);
  CPtrHolder<T>* holder = new CPtrHolder<T>(ptr);
  return reinterpret_cast<intptr_t>(holder);
}

template<typename T>
intptr_t toIntPtr(CPtrHolder<T>* holder) {
  return reinterpret_cast<intptr_t>(holder);
}

template<typename T>
intptr_t toIntPtr(const SharedPtr<T>& ptr) {
  if (ptr == nullptr) {
    return 0;
  }
  CPtrHolder<T>* holder = new CPtrHolder<T>(ptr);
  return reinterpret_cast<intptr_t>(holder);
}

template<typename T>
CPtrHolder<T>* toCPtrHolder(intptr_t handle) {
  if (handle == 0) {
    return nullptr;
  }
  return reinterpret_cast<CPtrHolder<T>*>(handle);
}

template<typename T>
SharedPtr<T> getCPtrHolderValue(intptr_t handle) {
  if (handle == 0) {
    return nullptr;
  }
  auto* holder = reinterpret_cast<CPtrHolder<T>*>(handle);
  return holder->get();
}

template<typename T>
void deleteCPtrHolder(intptr_t handle) {
  if (handle == 0) {
    return;
  }
  CPtrHolder<T>* holder = reinterpret_cast<CPtrHolder<T>*>(handle);
  if (holder != nullptr) {
    delete holder;
  }
}
